#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Rubber Duck harness installer"
echo
echo "Pick harness:"
echo "  1) opencode (verified)"
echo "  2) claude-code (scaffolded)"
echo "  3) github-copilot (scaffolded)"
echo "  4) pi (scaffolded)"
echo
read -r -p "Enter number [1-4]: " choice

case "$choice" in
  1)
    bash "$SCRIPT_DIR/install.sh" --opencode
    ;;
  2)
    bash "$SCRIPT_DIR/install.sh" --claude-code
    ;;
  3)
    bash "$SCRIPT_DIR/install.sh" --copilot
    ;;
  4)
    bash "$SCRIPT_DIR/install.sh" --pi
    ;;
  *)
    echo "Invalid choice: $choice" >&2
    exit 1
    ;;
esac
