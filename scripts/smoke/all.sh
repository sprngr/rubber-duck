#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

"$SCRIPT_DIR/claude-code.sh"
"$SCRIPT_DIR/opencode.sh"
"$SCRIPT_DIR/github-copilot.sh"
"$SCRIPT_DIR/pi.sh"

echo "[smoke] all adapters ok"
