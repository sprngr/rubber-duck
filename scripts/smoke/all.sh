#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

"$SCRIPT_DIR/claude-code.sh"
"$SCRIPT_DIR/copilot-cli.sh"
"$SCRIPT_DIR/codex.sh"
"$SCRIPT_DIR/cursor.sh"
"$SCRIPT_DIR/windsurf.sh"
"$SCRIPT_DIR/gemini-antigravity.sh"

echo "[smoke] all adapters ok"
