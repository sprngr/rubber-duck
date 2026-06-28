#!/usr/bin/env bash
set -euo pipefail

SMOKE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SMOKE_DIR/../.." && pwd)"

REQUIRED_COMMANDS=(
  "/quack"
  "/duck-review"
  "/duck-debug"
  "/duck-design"
  "/duck-explain"
  "/duck-teach"
  "/duck-triage"
)

REQUIRED_ARTIFACTS=(
  "AGENTS.md"
  "agents/*.agent.md"
  "skills/**"
)

fail() {
  echo "[smoke] error: $*" >&2
  exit 1
}

require_file() {
  local path="$1"
  [[ -f "$path" ]] || fail "missing file: $path"
}

require_line() {
  local needle="$1"
  local file="$2"
  if ! grep -Fq "$needle" "$file"; then
    fail "missing '$needle' in $file"
  fi
}

check_adapter() {
  local harness="$1"
  local adapter="$REPO_ROOT/adapters/$harness/adapter.yaml"
  local readme="$REPO_ROOT/adapters/$harness/README.md"

  require_file "$adapter"
  require_file "$readme"
  require_line "harness: $harness" "$adapter"

  for artifact in "${REQUIRED_ARTIFACTS[@]}"; do
    require_line "$artifact" "$adapter"
  done

  for cmd in "${REQUIRED_COMMANDS[@]}"; do
    require_line "$cmd" "$adapter"
  done

  echo "[smoke] $harness ok"
}
