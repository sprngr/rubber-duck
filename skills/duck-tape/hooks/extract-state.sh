#!/usr/bin/env bash
# duck-tape pre-compact transcript parser (Angle A: auto-checkpoint)
# Invoked by harness hook before context compaction.
# Parses session transcript and writes a real Agent State file.
# Supports Claude Code and Copilot JSONL transcripts.
# Falls back to marker-only write when jq missing, transcript missing,
# or parse error. Marker format matches pre-compact.sh.
set -euo pipefail

MAX_BYTES="${DUCK_TAPE_MAX_TRANSCRIPT_BYTES:-5242880}" # 5MB default
TRUSTED_ROOT="${DUCK_TAPE_TRUSTED_ROOT:-}"

# Resolve transcript path: $1 first, else stdin JSON transcript_path/transcriptPath.
transcript="${1:-}"
if [[ -z "$transcript" && ! -t 0 ]]; then
  stdin_json="$(cat)"
  if [[ -n "$stdin_json" ]]; then
    transcript="$(printf '%s' "$stdin_json" | jq -r '.transcript_path // .transcriptPath // empty' 2>/dev/null || true)"
  fi
fi

duck_tape_dir="${2:-$(pwd)/.duck-tape}"
mkdir -p "$duck_tape_dir"

if [[ ! -f "$duck_tape_dir/.gitignore" ]]; then
  printf '*\n' > "$duck_tape_dir/.gitignore"
fi

timestamp_utc="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
stamp="$(date -u +%Y-%m-%d-%H%M)"
cwd="$(pwd)"
state_file="$duck_tape_dir/${stamp}-auto.state.md"
marker="$duck_tape_dir/.last-compact"

canon_path() {
  local p="$1"
  if command -v realpath >/dev/null 2>&1; then
    realpath "$p" 2>/dev/null || return 1
  else
    python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$p" 2>/dev/null || return 1
  fi
}

write_marker_only() {
  local latest_state=""
  shopt -s nullglob
  local state_files=( "$duck_tape_dir"/*.state.md )
  shopt -u nullglob
  if (( ${#state_files[@]} > 0 )); then
    latest_state="$(basename -- "$(ls -t "$duck_tape_dir"/*.state.md 2>/dev/null | head -1)")"
  fi
  {
    printf '%s | cwd: %s' "$timestamp_utc" "$cwd"
    if [[ -n "$latest_state" ]]; then
      printf ' | latest-state: %s' "$latest_state"
    fi
    if [[ -n "$transcript" && -f "$transcript" ]]; then
      printf ' | transcript: %s' "$transcript"
    fi
    printf '\n'
  } > "$marker"
  printf '%s\n' "$marker"
}

# Require jq.
if ! command -v jq >/dev/null 2>&1; then
  write_marker_only
  exit 0
fi

# Require a readable transcript.
if [[ -z "$transcript" || ! -f "$transcript" ]]; then
  write_marker_only
  exit 0
fi

# Trust-boundary checks: canonical path under trusted root, no symlink, size cap.
if [[ -L "$transcript" ]]; then
  write_marker_only
  exit 0
fi
transcript_real="$(canon_path "$transcript" || true)"
if [[ -z "${transcript_real:-}" ]]; then
  write_marker_only
  exit 0
fi
if [[ -n "$TRUSTED_ROOT" ]]; then
  trusted_real="$(canon_path "$TRUSTED_ROOT" || true)"
  if [[ -z "${trusted_real:-}" ]]; then
    write_marker_only
    exit 0
  fi
  case "$transcript_real" in
    "$trusted_real"|"${trusted_real}/"*) ;;
    *)
      write_marker_only
      exit 0
      ;;
  esac
fi
size_bytes="$(wc -c < "$transcript" 2>/dev/null || echo 0)"
if ! [[ "$size_bytes" =~ ^[0-9]+$ ]] || (( size_bytes > MAX_BYTES )); then
  write_marker_only
  exit 0
fi

# Detect format by scanning first 50 lines for a discriminator.
# CC transcripts often start with metadata (ai-title, mode, file-history-snapshot)
# before the first message, so the first line alone is unreliable.
detect_format() {
  local t="$1"
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
  write_marker_only
  exit 0
fi

# Truncate to 200 chars, collapse newlines to spaces, escape markdown pipes.
truncate200() {
  local s="${1:0:200}"
  s="${s//$'\n'/ }"
  s="${s//$'\r'/ }"
  s="${s//|/\\|}"
  printf '%s' "$s"
}

redact_sensitive() {
  printf '%s' "$1" \
    | sed -E \
      -e 's/(ghp_[A-Za-z0-9_]{20,})/[REDACTED]/g' \
      -e 's/(github_pat_[A-Za-z0-9_]{20,})/[REDACTED]/g' \
      -e 's/([Aa]uthorization:[[:space:]]*[Bb]earer[[:space:]]+)[^[:space:]]+/\1[REDACTED]/g' \
      -e 's/([Aa][Pp][Ii][_ -]?[Kk]ey[[:space:]]*[:=][[:space:]]*)[^[:space:]]+/\1[REDACTED]/g' \
      -e 's/(AKIA[0-9A-Z]{16})/[REDACTED]/g' \
      -e 's/([Pp]assword[[:space:]]*[:=][[:space:]]*)[^[:space:]"'"'"'`,;]+/\1[REDACTED]/g' \
      -e 's/([Pp]ass(wd)?[[:space:]]*[:=][[:space:]]*)[^[:space:]"'"'"'`,;]+/\1[REDACTED]/g' \
      -e 's/([Pp]wd[[:space:]]*[:=][[:space:]]*)[^[:space:]"'"'"'`,;]+/\1[REDACTED]/g' \
      -e 's/([Ss]ecret[[:space:]]*[:=][[:space:]]*)[^[:space:]"'"'"'`,;]+/\1[REDACTED]/g' \
      -e 's/([Tt]oken[[:space:]]*[:=][[:space:]]*)[^[:space:]"'"'"'`,;]+/\1[REDACTED]/g' \
      -e 's/([Cc]lient[_ -]?[Ss]ecret[[:space:]]*[:=][[:space:]]*)[^[:space:]"'"'"'`,;]+/\1[REDACTED]/g' \
      -e 's/([Pp]rivate[_ -]?[Kk]ey[[:space:]]*[:=][[:space:]]*)[^[:space:]"'"'"'`,;]+/\1[REDACTED]/g' \
      -e 's#([a-z][a-z0-9+.-]*://[^:/[:space:]]+:)[^@/[:space:]]+@#\1[REDACTED]@#gI' \
      -e 's/\b((export[[:space:]]+)?[A-Z][A-Z0-9_]*(PASSWORD|PASSWD|PWD|SECRET|TOKEN|API_KEY|ACCESS_KEY|PRIVATE_KEY)[A-Z0-9_]*[[:space:]]*=[[:space:]]*)[^[:space:]"'"'"'`]+/\1[REDACTED]/g' \
      -e 's/\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b/[REDACTED]/g' \
      -e 's/\b(\+?[0-9]{1,3}[-.[:space:]]?)?(\(?[0-9]{3}\)?[-.[:space:]]?)?[0-9]{3}[-.[:space:]]?[0-9]{4}\b/[REDACTED]/g' \
      -e 's/\b[0-9]{3}-[0-9]{2}-[0-9]{4}\b/[REDACTED]/g'
}

# Extract via jq with fallback. On any jq error, drop to marker-only.
extract_claude_code() {
  local t="$1"
  local first_prompt tool_calls last_text decisions

  first_prompt="$(jq -r '
    select(.type=="user" and .message.role=="user" and (.message.content | type=="string"))
    | .message.content
  ' "$t" 2>/dev/null | grep -vE '^<' | head -1 || true)"

  tool_calls="$(jq -r '
    select(.type=="assistant")
    | .message.content[]?
    | select(.type=="tool_use")
    | .name + ": " + (.input.file_path // .input.command // .input.filePath // "unknown")
  ' "$t" 2>/dev/null || true)"

  last_text="$(jq -r '
    select(.type=="assistant")
    | .message.content[]?
    | select(.type=="text")
    | .text
  ' "$t" 2>/dev/null | tail -1 || true)"

  decisions="$(jq -r '
    select(.type=="assistant")
    | .message.content[]?
    | select(.type=="text")
    | .text
  ' "$t" 2>/dev/null \
    | grep -iE 'APPROVED|DECIDED|CHOSE|DECISION|we will use|going with|let'"'"'s go with' \
    | awk '!seen[$0]++' \
    | tail -10 || true)"

  render_state "$first_prompt" "$tool_calls" "$last_text" "$decisions"
}

extract_copilot() {
  local t="$1"
  local first_prompt tool_calls last_text decisions

  first_prompt="$(jq -r 'select(.type=="user.message") | .data.content' "$t" 2>/dev/null \
    | grep -vE '^<' | head -1 || true)"

  tool_calls="$(jq -r '
    select(.type=="assistant.message")
    | .data.toolRequests[]?
    | .name + ": " + (
        try (.arguments | fromjson | (.filePath // .command // .file_path // "unknown"))
        catch "unknown"
      )
  ' "$t" 2>/dev/null || true)"

  last_text="$(jq -r 'select(.type=="assistant.message") | .data.content' "$t" 2>/dev/null \
    | tail -1 || true)"

  decisions="$(jq -r 'select(.type=="assistant.message") | .data.content + "\n" + (.data.reasoningText // "")' "$t" 2>/dev/null \
    | grep -iE 'APPROVED|DECIDED|CHOSE|DECISION|we will use|going with|let'"'"'s go with' \
    | awk '!seen[$0]++' \
    | tail -10 || true)"

  render_state "$first_prompt" "$tool_calls" "$last_text" "$decisions"
}

render_state() {
  local first_prompt="$1" tool_calls="$2" last_text="$3" decisions="$4"
  local first_prompt_t last_text_t

  first_prompt="$(redact_sensitive "$first_prompt")"
  tool_calls="$(redact_sensitive "$tool_calls")"
  last_text="$(redact_sensitive "$last_text")"
  decisions="$(redact_sensitive "$decisions")"

  if [[ -z "$first_prompt" && -z "$tool_calls" && -z "$last_text" ]]; then
    # Nothing extracted; marker-only.
    return 1
  fi

  first_prompt_t="$(truncate200 "$first_prompt")"
  last_text_t="$(truncate200 "$last_text")"

  {
    printf '# Agent State\n\n'
    printf 'Session: %s-auto | Cwd: %s | Trigger: pre-compact-auto\n' "$stamp" "$cwd"
    printf 'Created: %s\n\n' "$timestamp_utc"
    printf '## Approved Workflow\n'
    if [[ -n "$first_prompt_t" ]]; then
      printf '%s\n\n' "$first_prompt_t"
    else
      printf '(not derivable from transcript)\n\n'
    fi
    printf '## Position\n'
    printf -- '- **Current:** %s\n' "$last_text_t"
    printf -- '- **Done:**\n'
    if [[ -n "$tool_calls" ]]; then
      while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        printf '  - %s (%s)\n' "$line" "$timestamp_utc"
      done <<< "$tool_calls"
    else
      printf '  (none extracted)\n'
    fi
    printf -- '- **Remaining:** (not derivable from transcript)\n\n'
    printf '## Decision Log\n'
    if [[ -n "$decisions" ]]; then
      while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        local snippet
        snippet="$(truncate200 "$line")"
        printf '%s AUTO-EXTRACTED: %s\n' "$timestamp_utc" "$snippet"
      done <<< "$decisions"
    else
      printf '(none detected)\n\n'
    fi
    printf '\n## Established Facts\n'
    printf '(auto-extracted; not reliably derivable from transcript shell parsing)\n\n'
    printf '## Re-derivation\n'
    printf 'Read transcript at %s for full session content.\n' "$transcript"
    printf 'Read latest manual state file in .duck-tape/ for higher-fidelity checkpoint.\n\n'
    printf '## Suggested Skills\n'
    printf -- '- duck-tape (run /duck-tape for full state before next compaction)\n'
  } > "$state_file"

  # Rotation cap: 10 files. Eviction precedence: auto, recovered, manual.
  # Exclude the just-written state file so the fresh checkpoint survives.
  shopt -s nullglob
  local all=( "$duck_tape_dir"/*.state.md )
  shopt -u nullglob
  local count=${#all[@]}
  while (( count > 10 )); do
    # Oldest auto file first (skip just-written file).
    local oldest_auto
    oldest_auto="$(ls -t "$duck_tape_dir"/*-auto.state.md 2>/dev/null | grep -vxF "$state_file" | tail -1 || true)"
    if [[ -n "$oldest_auto" ]]; then
      rm -f "$oldest_auto"
    else
      # No auto files; oldest recovered next (skip just-written file).
      local oldest_recovered
      oldest_recovered="$(ls -t "$duck_tape_dir"/*-recovered.state.md 2>/dev/null | grep -vxF "$state_file" | tail -1 || true)"
      if [[ -n "$oldest_recovered" ]]; then
        rm -f "$oldest_recovered"
      else
        # No auto or recovered; drop oldest manual (skip just-written file).
        local oldest
        oldest="$(ls -t "$duck_tape_dir"/*.state.md 2>/dev/null | grep -vxF "$state_file" | tail -1 || true)"
        [[ -n "$oldest" ]] && rm -f "$oldest"
      fi
    fi
    count=$((count - 1))
  done

  # Marker points at newest state file.
  local latest
  latest="$(basename -- "$(ls -t "$duck_tape_dir"/*.state.md 2>/dev/null | head -1)")"
  {
    printf '%s | cwd: %s | latest-state: %s' "$timestamp_utc" "$cwd" "$latest"
    if [[ -n "$transcript" && -f "$transcript" ]]; then
      printf ' | transcript: %s' "$transcript"
    fi
    printf '\n'
  } > "$marker"
  printf '%s\n' "$state_file"
}

case "$format" in
  claude-code)
    if ! extract_claude_code "$transcript"; then
      write_marker_only
    fi
    ;;
  copilot)
    if ! extract_copilot "$transcript"; then
      write_marker_only
    fi
    ;;
  *)
    write_marker_only
    ;;
esac
