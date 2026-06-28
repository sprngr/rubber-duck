#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

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

HARNESSES=(
  "opencode"
  "claude-code"
  "github-copilot"
  "pi"
)

VALID_STATUSES=(
  "verified"
  "scaffolded"
)

fail() {
  echo "[build-adapters] error: $*" >&2
  exit 1
}

require_line() {
  local needle="$1"
  local file="$2"
  if ! grep -Fq "$needle" "$file"; then
    fail "missing '$needle' in $file"
  fi
}

echo "[build-adapters] validating command specification"
SPEC_FILE="$REPO_ROOT/docs/install/command-spec.md"
[[ -f "$SPEC_FILE" ]] || fail "missing $SPEC_FILE"

for cmd in "${REQUIRED_COMMANDS[@]}"; do
  require_line "$cmd" "$SPEC_FILE"
done

echo "[build-adapters] validating adapters"
for harness in "${HARNESSES[@]}"; do
  ADAPTER_FILE="$REPO_ROOT/adapters/$harness/adapter.yaml"
  README_FILE="$REPO_ROOT/adapters/$harness/README.md"

  [[ -f "$ADAPTER_FILE" ]] || fail "missing $ADAPTER_FILE"
  [[ -f "$README_FILE" ]] || fail "missing $README_FILE"

  require_line "harness: $harness" "$ADAPTER_FILE"

  status_ok=false
  found_status=""
  for s in "${VALID_STATUSES[@]}"; do
    if grep -Fq "status: $s" "$ADAPTER_FILE"; then
      status_ok=true
      found_status="$s"
      break
    fi
  done
  [[ "$status_ok" == true ]] || fail "invalid status in $ADAPTER_FILE (expected verified|scaffolded)"

  if [[ "$found_status" == "verified" ]]; then
    if grep -Fq "plugin_artifacts:" "$ADAPTER_FILE"; then
      fail "verified adapter $harness should not declare plugin_artifacts"
    fi
  fi

  for artifact in "${REQUIRED_ARTIFACTS[@]}"; do
    require_line "$artifact" "$ADAPTER_FILE"
  done

  for cmd in "${REQUIRED_COMMANDS[@]}"; do
    require_line "$cmd" "$ADAPTER_FILE"
  done
done

echo "[build-adapters] ok"
