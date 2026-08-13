#!/usr/bin/env bash
# duck-tape raw transcript extractor (Angle B: LLM-assisted recovery)
# Reads a session transcript, extracts raw material into structured markdown
# for LLM synthesis during /duck-tape resume. Does NOT synthesize state.
#
# Supports three input formats:
#   - Claude Code JSONL (one JSON object per line, message.role present)
#   - Copilot JSONL (one JSON object per line, type:"user.message"/"assistant.message")
#   - opencode JSON array (single JSON document, [{ info, parts }])
#
# Outputs structured markdown to stdout. Requires jq.
# Falls back to "transcript too large, read manually" message if jq missing
# or transcript unreadable.
set -euo pipefail

MAX_BYTES="${DUCK_TAPE_MAX_TRANSCRIPT_BYTES:-5242880}" # 5MB default
TRUSTED_ROOT="${DUCK_TAPE_TRUSTED_ROOT:-$(pwd)}"

canon_path() {
  local p="$1"
  if command -v realpath >/dev/null 2>&1; then
    realpath "$p" 2>/dev/null || return 1
  else
    python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$p" 2>/dev/null || return 1
  fi
}

# Redact common secret patterns from all stdout lines.
exec > >(sed -E \
  -e 's/(ghp_[A-Za-z0-9_]{20,})/[REDACTED]/g' \
  -e 's/(github_pat_[A-Za-z0-9_]{20,})/[REDACTED]/g' \
  -e 's/([Aa]uthorization:[[:space:]]*[Bb]earer[[:space:]]+)[^[:space:]]+/\1[REDACTED]/g' \
  -e 's/([Aa][Pp][Ii][_ -]?[Kk]ey[[:space:]]*[:=][[:space:]]*)[^[:space:]]+/\1[REDACTED]/g' \
  -e 's/(AKIA[0-9A-Z]{16})/[REDACTED]/g')

transcript="${1:-}"
if [[ -z "$transcript" || ! -f "$transcript" ]]; then
  printf 'Transcript not found: %s\n' "${transcript:-<none>}" >&2
  printf '# Transcript Raw Material\n\nTranscript not available. Read session manually.\n'
  exit 0
fi

if ! command -v jq >/dev/null 2>&1; then
  printf '# Transcript Raw Material\n\njq missing. Read transcript manually: %s\n' "$transcript"
  exit 0
fi

# Trust-boundary checks: canonical path under trusted root, no symlink, size cap.
if [[ -L "$transcript" ]]; then
  printf '# Transcript Raw Material\n\nTranscript not available. Read session manually.\n'
  exit 0
fi
transcript_real="$(canon_path "$transcript" || true)"
trusted_real="$(canon_path "$TRUSTED_ROOT" || true)"
if [[ -z "${transcript_real:-}" || -z "${trusted_real:-}" ]]; then
  printf '# Transcript Raw Material\n\nTranscript not available. Read session manually.\n'
  exit 0
fi
case "$transcript_real" in
  "$trusted_real"|"${trusted_real}/"*) ;;
  *) printf '# Transcript Raw Material\n\nTranscript not available. Read session manually.\n'; exit 0 ;;
esac
size_bytes="$(wc -c < "$transcript" 2>/dev/null || echo 0)"
if ! [[ "$size_bytes" =~ ^[0-9]+$ ]] || (( size_bytes > MAX_BYTES )); then
  printf '# Transcript Raw Material\n\nTranscript not available. Read session manually.\n'; exit 0
fi

# Detect format.
# opencode snapshot = single JSON array (not JSONL). Detect by first non-space char.
# CC/Copilot = JSONL. CC has "message":"role", Copilot has "type":"*.message".
detect_format() {
  local t="$1"
  local first
  first="$(head -c 1 "$t" 2>/dev/null || true)"
  if [[ "$first" == "[" ]]; then
    printf 'opencode'
    return 0
  fi
  local i=0 line
  while IFS= read -r line; do
    i=$((i + 1))
    (( i > 50 )) && break
    [[ -z "$line" ]] && continue
    if [[ "$line" == *'"type":"session.start"'* ]]; then
      printf 'copilot'
      return 0
    fi
    if [[ "$line" == *'"message"'* && "$line" == *'"role"'* ]]; then
      printf 'claude-code'
      return 0
    fi
  done < "$t"
  printf 'unknown'
}

format="$(detect_format "$transcript")"

if [[ "$format" == "unknown" ]]; then
  printf '# Transcript Raw Material\n\nFormat unknown. Read transcript manually: %s\n' "$transcript"
  exit 0
fi

# Session metadata block. Best-effort; fields optional.
session_meta() {
  local t="$1" fmt="$2"
  local start="" cwd="" branch=""
  if [[ "$fmt" == "claude-code" ]]; then
    start="$(jq -r 'select(.type=="user") | .timestamp' "$t" 2>/dev/null | head -1 || true)"
  elif [[ "$fmt" == "copilot" ]]; then
    start="$(jq -r 'select(.type=="session.start") | .timestamp' "$t" 2>/dev/null | head -1 || true)"
  elif [[ "$fmt" == "opencode" ]]; then
    # info.time.created is epoch ms; convert to ISO if possible.
    start="$(jq -r 'if length > 0 then (.[0].info.time.created // empty) else empty end' "$t" 2>/dev/null || true)"
    if [[ "$start" =~ ^[0-9]+$ ]] && command -v date >/dev/null 2>&1; then
      start="$(date -u -d "@$((start / 1000))" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "$start")"
    fi
  fi
  cwd="$(pwd)"
  branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
  printf '## Session Metadata\n'
  printf -- '- Start: %s\n' "${start:-unknown}"
  printf -- '- Cwd: %s\n' "$cwd"
  printf -- '- Branch: %s\n\n' "${branch:-unknown}"
}

extract_claude_code() {
  local t="$1"
  printf '# Transcript Raw Material\n\n'

  printf '## User Prompts (chronological)\n'
  local idx=0
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    idx=$((idx + 1))
    printf '%d. %s\n' "$idx" "$line"
  done < <(jq -r '
    select(.type=="user" and .message.role=="user" and (.message.content | type=="string"))
    | .timestamp + ": " + .message.content
  ' "$t" 2>/dev/null || true)
  printf '\n'

  printf '## Tool Calls (chronological)\n'
  idx=0
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    idx=$((idx + 1))
    printf '%d. %s\n' "$idx" "$line"
  done < <(jq -r '
    select(.type=="assistant")
    | .timestamp as $ts
    | .message.content[]?
    | select(.type=="tool_use")
    | $ts + ": " + .name + " on " + (.input.file_path // .input.command // .input.filePath // "unknown")
  ' "$t" 2>/dev/null || true)
  printf '\n'

  printf '## Assistant Messages (last 10, chronological)\n'
  idx=0
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    idx=$((idx + 1))
    printf '%d. %s\n' "$idx" "$line"
  done < <(jq -r '
    select(.type=="assistant")
    | .timestamp + ": " + (.message.content[]? | select(.type=="text") | .text)
  ' "$t" 2>/dev/null | tail -10 || true)
  printf '\n'

  printf '## Potential Decisions (all matching, chronological, deduped)\n'
  idx=0
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    idx=$((idx + 1))
    printf '%d. %s\n' "$idx" "$line"
  done < <(jq -r '
    select(.type=="assistant")
    | .timestamp + ": " + (.message.content[]? | select(.type=="text") | .text)
  ' "$t" 2>/dev/null \
    | grep -iE 'APPROVED|DECIDED|CHOSE|DECISION|we will use|going with|let'"'"'s go with' \
    | awk '!seen[$0]++' || true)
  printf '\n'

  printf '## Failed Tool Results\n'
  idx=0
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    idx=$((idx + 1))
    printf '%d. %s\n' "$idx" "$line"
  done < <(jq -r '
    select(.type=="user")
    | .message.content[]?
    | select(.type=="tool_result" and (.is_error // false) == true)
    | (.content | if type=="string" then . else (.[]? | select(.type=="text") | .text) end)
  ' "$t" 2>/dev/null || true)
  printf '\n'

  session_meta "$t" "claude-code"
}

extract_copilot() {
  local t="$1"
  printf '# Transcript Raw Material\n\n'

  printf '## User Prompts (chronological)\n'
  local idx=0
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    idx=$((idx + 1))
    printf '%d. %s\n' "$idx" "$line"
  done < <(jq -r 'select(.type=="user.message") | .timestamp + ": " + .data.content' "$t" 2>/dev/null || true)
  printf '\n'

  printf '## Tool Calls (chronological)\n'
  idx=0
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    idx=$((idx + 1))
    printf '%d. %s\n' "$idx" "$line"
  done < <(jq -r '
    select(.type=="assistant.message")
    | .timestamp as $ts
    | .data.toolRequests[]?
    | $ts + ": " + .name + " on " + (
        try (.arguments | fromjson | (.filePath // .command // .file_path // "unknown"))
        catch "unknown"
      )
  ' "$t" 2>/dev/null || true)
  printf '\n'

  printf '## Assistant Messages (last 10, chronological)\n'
  idx=0
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    idx=$((idx + 1))
    printf '%d. %s\n' "$idx" "$line"
  done < <(jq -r 'select(.type=="assistant.message") | .timestamp + ": " + .data.content' "$t" 2>/dev/null | tail -10 || true)
  printf '\n'

  printf '## Potential Decisions (all matching, chronological, deduped)\n'
  idx=0
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    idx=$((idx + 1))
    printf '%d. %s\n' "$idx" "$line"
  done < <(jq -r 'select(.type=="assistant.message") | .timestamp + ": " + (.data.content + "\n" + (.data.reasoningText // ""))' "$t" 2>/dev/null \
    | grep -iE 'APPROVED|DECIDED|CHOSE|DECISION|we will use|going with|let'"'"'s go with' \
    | awk '!seen[$0]++' || true)
  printf '\n'

  printf '## Failed Tool Results\n'
  idx=0
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    idx=$((idx + 1))
    printf '%d. %s\n' "$idx" "$line"
  done < <(jq -r '
    select(.type=="tool.message")
    | select(.data.isError == true)
    | .timestamp + ": " + (.data.content // .data.error // "unknown error")
  ' "$t" 2>/dev/null || true)
  printf '\n'

  session_meta "$t" "copilot"
}

extract_opencode() {
  local t="$1"
  printf '# Transcript Raw Material\n\n'

  # opencode snapshot: single JSON array of { info, parts }.
  # info.time.created is epoch ms. Convert to ISO 8601 UTC via jq strftime.
  printf '## User Prompts (chronological)\n'
  local idx=0
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    idx=$((idx + 1))
    printf '%d. %s\n' "$idx" "$line"
  done < <(jq -r '
    .[]
    | select(.info.role=="user")
    | (try ((.info.time.created // 0) / 1000 | todateiso8601) catch ((.info.time.created // 0 | tostring)))
    + ": " + (.parts[]? | select(.type=="text") | .text)
  ' "$t" 2>/dev/null || true)
  printf '\n'

  printf '## Tool Calls (chronological)\n'
  idx=0
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    idx=$((idx + 1))
    printf '%d. %s\n' "$idx" "$line"
  done < <(jq -r '
    .[]
    | select(.info.role=="assistant")
    | (try ((.info.time.created // 0) / 1000 | todateiso8601) catch ((.info.time.created // 0 | tostring))) as $ts
    | .parts[]?
    | select(.type=="tool")
    | $ts + ": " + (.tool // "unknown") + " on " + ((.state.input.file_path // .state.input.command // .state.input.filePath // "unknown") // "unknown")
  ' "$t" 2>/dev/null || true)
  printf '\n'

  printf '## Assistant Messages (last 10, chronological)\n'
  idx=0
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    idx=$((idx + 1))
    printf '%d. %s\n' "$idx" "$line"
  done < <(jq -r '
    .[]
    | select(.info.role=="assistant")
    | (try ((.info.time.created // 0) / 1000 | todateiso8601) catch ((.info.time.created // 0 | tostring)))
    + ": " + (.parts[]? | select(.type=="text") | .text)
  ' "$t" 2>/dev/null | tail -10 || true)
  printf '\n'

  printf '## Potential Decisions (all matching, chronological, deduped)\n'
  idx=0
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    idx=$((idx + 1))
    printf '%d. %s\n' "$idx" "$line"
  done < <(jq -r '
    .[]
    | select(.info.role=="assistant")
    | (try ((.info.time.created // 0) / 1000 | todateiso8601) catch ((.info.time.created // 0 | tostring)))
    + ": " + (.parts[]? | select(.type=="text") | .text)
  ' "$t" 2>/dev/null \
    | grep -iE 'APPROVED|DECIDED|CHOSE|DECISION|we will use|going with|let'"'"'s go with' \
    | awk '!seen[$0]++' || true)
  printf '\n'

  printf '## Failed Tool Results\n'
  idx=0
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    idx=$((idx + 1))
    printf '%d. %s\n' "$idx" "$line"
  done < <(jq -r '
    .[]
    | select(.info.role=="assistant")
    | (try ((.info.time.created // 0) / 1000 | todateiso8601) catch ((.info.time.created // 0 | tostring))) as $ts
    | .parts[]?
    | select(.type=="tool")
    | select(.state.status == "error" or .state.error != null)
    | $ts + ": " + (.tool // "unknown") + ": " + ((.state.error // .state.output // "unknown error") | if type=="string" then . else tostring end)
  ' "$t" 2>/dev/null || true)
  printf '\n'

  session_meta "$t" "opencode"
}

case "$format" in
  claude-code) extract_claude_code "$transcript" ;;
  copilot)     extract_copilot "$transcript" ;;
  opencode)    extract_opencode "$transcript" ;;
  *)           printf '# Transcript Raw Material\n\nFormat unknown.\n' ;;
esac
