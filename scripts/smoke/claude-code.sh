#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/smoke/common.sh
source "$SCRIPT_DIR/common.sh"

check_adapter "claude-code"

require_file "$REPO_ROOT/adapters/claude-code/claude-plugin.yaml"
require_file "$REPO_ROOT/adapters/claude-code/commands.yaml"
require_line "status: scaffolded" "$REPO_ROOT/adapters/claude-code/adapter.yaml"

echo "[smoke] claude-code scaffold ok"
