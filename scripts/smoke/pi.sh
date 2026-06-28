#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/smoke/common.sh
source "$SCRIPT_DIR/common.sh"

check_adapter "pi"

require_file "$REPO_ROOT/adapters/pi/pi-plugin.yaml"
require_file "$REPO_ROOT/adapters/pi/commands.yaml"
require_line "status: scaffolded" "$REPO_ROOT/adapters/pi/adapter.yaml"

echo "[smoke] pi scaffold ok"
