#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Install Rubber Duck artifacts into selected harness config path.

Usage:
  bash scripts/install.sh [options]

Options:
  --prefix <path>   Base config directory (default: host-dependent)
  --opencode        Target OpenCode path (${XDG_CONFIG_HOME:-$HOME/.config}/opencode) (default)
  --claude-code     Target Claude Code path (${XDG_CONFIG_HOME:-$HOME/.config}/claude-code)
  --copilot         Target GitHub Copilot path (${XDG_CONFIG_HOME:-$HOME/.config}/copilot)
  --pi              Target Pi path (${XDG_CONFIG_HOME:-$HOME/.config}/pi)
  --skills-only     Install only skills/
  --agents-only     Install only agents/*.agent.md (router + subagents)
  --policy-only     Install only AGENTS.md
  --dry-run         Print planned actions without writing files
  --force           Overwrite existing target files without prompt
  -h, --help        Show this help
EOF
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

HOST="opencode"
PREFIX="${XDG_CONFIG_HOME:-$HOME/.config}/opencode"
TARGET_ROOT=""
DRY_RUN=false
FORCE=false

INSTALL_POLICY=true
INSTALL_AGENTS=true
INSTALL_SKILLS=true
MODE_SELECTED=false

set_mode() {
  if [[ "$MODE_SELECTED" == false ]]; then
    INSTALL_POLICY=false
    INSTALL_AGENTS=false
    INSTALL_SKILLS=false
    MODE_SELECTED=true
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --prefix)
      if [[ $# -lt 2 ]]; then
        echo "error: --prefix requires a value" >&2
        exit 1
      fi
      PREFIX="$2"
      shift 2
      ;;
    --opencode)
      HOST="opencode"
      PREFIX="${XDG_CONFIG_HOME:-$HOME/.config}/opencode"
      shift
      ;;
    --claude-code)
      HOST="claude-code"
      PREFIX="${XDG_CONFIG_HOME:-$HOME/.config}/claude-code"
      shift
      ;;
    --copilot)
      HOST="github-copilot"
      PREFIX="${XDG_CONFIG_HOME:-$HOME/.config}/copilot"
      shift
      ;;
    --pi)
      HOST="pi"
      PREFIX="${XDG_CONFIG_HOME:-$HOME/.config}/pi"
      shift
      ;;
    --skills-only)
      set_mode
      INSTALL_SKILLS=true
      shift
      ;;
    --agents-only)
      set_mode
      INSTALL_AGENTS=true
      shift
      ;;
    --policy-only)
      set_mode
      INSTALL_POLICY=true
      shift
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --force)
      FORCE=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "error: unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

TARGET_ROOT="$PREFIX/rubber-duck"

run() {
  if [[ "$DRY_RUN" == true ]]; then
    printf '[dry-run]'
    for arg in "$@"; do
      printf ' %q' "$arg"
    done
    printf '\n'
  else
    "$@"
  fi
}

confirm_overwrite() {
  local path="$1"
  if [[ ! -e "$path" || "$FORCE" == true ]]; then
    return 0
  fi

  read -r -p "Target exists: $path. Overwrite? [y/N] " ans
  case "$ans" in
    y|Y|yes|YES)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

copy_file() {
  local src="$1"
  local dst="$2"

  if ! confirm_overwrite "$dst"; then
    echo "skip: $dst"
    return
  fi

  run mkdir -p "$(dirname "$dst")"
  run cp "$src" "$dst"
  echo "installed: $dst"
}

copy_dir() {
  local src="$1"
  local dst="$2"

  if ! confirm_overwrite "$dst"; then
    echo "skip: $dst"
    return
  fi

  run mkdir -p "$(dirname "$dst")"
  run rm -rf "$dst"
  run cp -R "$src" "$dst"
  echo "installed: $dst"
}

echo "Installing Rubber Duck into: $TARGET_ROOT"

if [[ "$INSTALL_POLICY" == true ]]; then
  copy_file "$REPO_ROOT/AGENTS.md" "$TARGET_ROOT/AGENTS.md"
fi

if [[ "$INSTALL_AGENTS" == true ]]; then
  run mkdir -p "$TARGET_ROOT/agents"
  for f in "$REPO_ROOT"/agents/*.agent.md; do
    copy_file "$f" "$TARGET_ROOT/agents/$(basename "$f")"
  done
fi

if [[ "$INSTALL_SKILLS" == true ]]; then
  copy_dir "$REPO_ROOT/skills" "$TARGET_ROOT/skills"
fi

case "$HOST" in
  "claude-code")
    run mkdir -p "$TARGET_ROOT/adapters/claude-code"
    copy_file "$REPO_ROOT/adapters/claude-code/claude-plugin.yaml" "$TARGET_ROOT/adapters/claude-code/claude-plugin.yaml"
    copy_file "$REPO_ROOT/adapters/claude-code/commands.yaml" "$TARGET_ROOT/adapters/claude-code/commands.yaml"
    ;;
  "github-copilot")
    run mkdir -p "$TARGET_ROOT/adapters/github-copilot"
    copy_file "$REPO_ROOT/adapters/github-copilot/copilot-plugin.yaml" "$TARGET_ROOT/adapters/github-copilot/copilot-plugin.yaml"
    copy_file "$REPO_ROOT/adapters/github-copilot/commands.yaml" "$TARGET_ROOT/adapters/github-copilot/commands.yaml"
    ;;
  "pi")
    run mkdir -p "$TARGET_ROOT/adapters/pi"
    copy_file "$REPO_ROOT/adapters/pi/pi-plugin.yaml" "$TARGET_ROOT/adapters/pi/pi-plugin.yaml"
    copy_file "$REPO_ROOT/adapters/pi/commands.yaml" "$TARGET_ROOT/adapters/pi/commands.yaml"
    ;;
esac

echo "Done."
echo "Install root: $TARGET_ROOT"
