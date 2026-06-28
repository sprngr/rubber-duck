#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/smoke/common.sh
source "$SCRIPT_DIR/common.sh"

check_adapter "github-copilot"

require_file "$REPO_ROOT/adapters/github-copilot/copilot-plugin.yaml"
require_file "$REPO_ROOT/adapters/github-copilot/commands.yaml"
require_line "status: scaffolded" "$REPO_ROOT/adapters/github-copilot/adapter.yaml"

echo "[smoke] github-copilot scaffold ok"
