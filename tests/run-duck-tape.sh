#!/usr/bin/env bash
# duck-tape hooks behavioral tests (bash surface: extract-state.sh + extract-raw.sh)
# Runs against fixtures, normalizes volatile fields, diffs against expected/ golden files.
set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
hooks_dir="$repo_root/skills/duck-tape/hooks"
fixtures="$script_dir/fixtures"
expected="$script_dir/expected"

failures=0

# Normalize volatile fields in a file or stdin -> stdout.
# Replaces: hook timestamps, stamps, cwd, transcript path, branch.
normalize() {
  local cwd="$1" transcript="$2" is_state="${3:-false}" is_raw="${4:-false}"
  local content
  # Preserve trailing newlines (command substitution strips them).
  content="$(cat; printf x)"
  content="${content%x}"
  # Hook execution timestamps (ISO 8601 UTC) -> __TIMESTAMP__
  # Only normalize in state files/marker where all timestamps are hook-time.
  # In raw output, transcript timestamps are deterministic from fixtures.
  if [[ "$is_state" == "true" ]]; then
    content="$(printf '%s' "$content" | sed -E 's/[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z/__TIMESTAMP__/g'; printf x)"
    content="${content%x}"
    content="$(printf '%s' "$content" | sed -E 's/[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{4}/__STAMP__/g'; printf x)"
    content="${content%x}"
  fi
  # Cwd path -> __CWD__
  content="${content//"$cwd"/__CWD__}"
  # Transcript path -> __TRANSCRIPT__
  content="${content//"$transcript"/__TRANSCRIPT__}"
  # Branch -> __BRANCH__ (only meaningful in raw output Session Metadata)
  if [[ "$is_raw" == "true" ]]; then
    content="$(printf '%s' "$content" | sed -E 's/^(- Branch:) .*/\1 __BRANCH__/'; printf x)"
    content="${content%x}"
  fi
  printf '%s' "$content"
}

assert_diff() {
  local label="$1" actual_file="$2" expected_file="$3"
  if diff "$actual_file" "$expected_file" >/dev/null 2>&1; then
    printf '  PASS: %s\n' "$label"
  else
    printf '  FAIL: %s\n' "$label" >&2
    diff "$actual_file" "$expected_file" >&2 || true
    failures=$((failures + 1))
  fi
}

test_extract_state() {
  local format="$1" fixture="$2" state_expected="$3" marker_expected="$4"
  printf '\n=== extract-state.sh (%s) ===\n' "$format"

  local tmpdir
  tmpdir="$(mktemp -d)"
  local duck_tape="$tmpdir/.duck-tape"

  # Run from temp dir (non-git) so branch is deterministic "unknown".
  local output
  output="$(cd "$tmpdir" && bash "$hooks_dir/extract-state.sh" "$fixture" "$duck_tape" 2>&1)" || true

  local state_file
  state_file="$duck_tape/$(ls "$duck_tape" | grep -E '^[0-9].*-auto\.state\.md$' | head -1)"

  if [[ ! -f "$state_file" ]]; then
    printf '  FAIL: no state file produced\n' >&2
    printf '  output: %s\n' "$output" >&2
    failures=$((failures + 1))
    rm -rf "$tmpdir"
    return
  fi

  normalize "$tmpdir" "$fixture" "true" "false" < "$state_file" > "$tmpdir/state.norm"
  normalize "$tmpdir" "$fixture" "true" "false" < "$duck_tape/.last-compact" > "$tmpdir/marker.norm"
  assert_diff "state file" "$tmpdir/state.norm" "$expected/$state_expected"
  assert_diff "marker" "$tmpdir/marker.norm" "$expected/$marker_expected"

  rm -rf "$tmpdir"
}

test_extract_raw() {
  local format="$1" fixture="$2" raw_expected="$3"
  printf '\n=== extract-raw.sh (%s) ===\n' "$format"

  local tmpdir
  tmpdir="$(mktemp -d)"

  local raw_output
  raw_output="$(cd "$tmpdir" && bash "$hooks_dir/extract-raw.sh" "$fixture" 2>&1; printf x)"
  raw_output="${raw_output%x}"

  printf '%s' "$raw_output" | normalize "$tmpdir" "$fixture" "false" "true" > "$tmpdir/raw.norm"
  assert_diff "raw output" "$tmpdir/raw.norm" "$expected/$raw_expected"

  rm -rf "$tmpdir"
}

printf '### duck-tape hook tests (bash) ###\n'

test_extract_state "claude-code" "$fixtures/cc-transcript.jsonl" "cc-state.md" "cc-marker.txt"
test_extract_state "copilot" "$fixtures/copilot-transcript.jsonl" "copilot-state.md" "copilot-marker.txt"
test_extract_raw "claude-code" "$fixtures/cc-transcript.jsonl" "cc-raw.md"
test_extract_raw "copilot" "$fixtures/copilot-transcript.jsonl" "copilot-raw.md"
test_extract_raw "opencode" "$fixtures/opencode-snapshot.json" "opencode-raw.md"

printf '\n=== Results: %d failure(s) ===\n' "$failures"
exit "$failures"
