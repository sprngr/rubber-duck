#!/usr/bin/env bash
# duck-tape pre-compact trigger
# Invoked by harness hook before context compaction.
# Writes .duck-tape/.last-compact marker only. No state stub, no merge.
# Skill reads marker at session resume to detect compaction occurred.
set -euo pipefail

duck_tape_dir="${1:-$(pwd)/.duck-tape}"
mkdir -p "$duck_tape_dir"

# .gitignore if missing
if [[ ! -f "$duck_tape_dir/.gitignore" ]]; then
  printf '*\n' > "$duck_tape_dir/.gitignore"
fi

timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
cwd="$(pwd)"

# Find latest existing state file, if any
latest_state=""
shopt -s nullglob
state_files=( "$duck_tape_dir"/*.state.md )
shopt -u nullglob
if (( ${#state_files[@]} > 0 )); then
  latest_state="$(basename -- "$(ls -t "$duck_tape_dir"/*.state.md 2>/dev/null | head -1)")"
fi

# Write compaction marker
marker="$duck_tape_dir/.last-compact"
{
  printf '%s | cwd: %s' "$timestamp" "$cwd"
  if [[ -n "$latest_state" ]]; then
    printf ' | latest-state: %s' "$latest_state"
  fi
  printf '\n'
} > "$marker"

printf '%s\n' "$marker"
