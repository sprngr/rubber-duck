#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Uninstall Rubber Duck artifacts from selected harness config path.

Usage:
  bash scripts/uninstall.sh [options]

Options:
  --prefix <path>   Base config directory (default: host-dependent)
  --opencode        Target OpenCode path (${XDG_CONFIG_HOME:-$HOME/.config}/opencode) (default)
  --claude-code     Target Claude Code path (${XDG_CONFIG_HOME:-$HOME/.config}/claude-code)
  --copilot         Target GitHub Copilot path (${XDG_CONFIG_HOME:-$HOME/.config}/copilot)
  --pi              Target Pi path (${XDG_CONFIG_HOME:-$HOME/.config}/pi)
  --skills-only     Remove only skills/
  --agents-only     Remove only agents/*.agent.md
  --policy-only     Remove only AGENTS.md
  --dry-run         Print planned actions without deleting
  --force           Delete without prompt
  -h, --help        Show this help
EOF
}

HOST="opencode"
PREFIX="${XDG_CONFIG_HOME:-$HOME/.config}/opencode"
TARGET_ROOT=""
DRY_RUN=false
FORCE=false

REMOVE_POLICY=true
REMOVE_AGENTS=true
REMOVE_SKILLS=true
MODE_SELECTED=false

set_mode() {
  if [[ "$MODE_SELECTED" == false ]]; then
    REMOVE_POLICY=false
    REMOVE_AGENTS=false
    REMOVE_SKILLS=false
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
      REMOVE_SKILLS=true
      shift
      ;;
    --agents-only)
      set_mode
      REMOVE_AGENTS=true
      shift
      ;;
    --policy-only)
      set_mode
      REMOVE_POLICY=true
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

confirm_remove() {
  local path="$1"
  if [[ "$FORCE" == true ]]; then
    return 0
  fi
  read -r -p "Remove: $path ? [y/N] " ans
  case "$ans" in
    y|Y|yes|YES)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

remove_path() {
  local path="$1"
  if [[ ! -e "$path" ]]; then
    echo "skip (not found): $path"
    return
  fi

  if ! confirm_remove "$path"; then
    echo "skip: $path"
    return
  fi

  run rm -rf "$path"
  echo "removed: $path"
}

cleanup_empty_dir() {
  local path="$1"
  if [[ -d "$path" ]] && [[ -z "$(ls -A "$path")" ]]; then
    run rmdir "$path"
    echo "removed empty dir: $path"
  fi
}

echo "Uninstalling Rubber Duck from: $TARGET_ROOT"

if [[ "$REMOVE_POLICY" == true ]]; then
  remove_path "$TARGET_ROOT/AGENTS.md"
fi

if [[ "$REMOVE_AGENTS" == true ]]; then
  remove_path "$TARGET_ROOT/agents"
fi

if [[ "$REMOVE_SKILLS" == true ]]; then
  remove_path "$TARGET_ROOT/skills"
fi

case "$HOST" in
  "claude-code") remove_path "$TARGET_ROOT/adapters/claude-code" ;;
  "github-copilot") remove_path "$TARGET_ROOT/adapters/github-copilot" ;;
  "pi") remove_path "$TARGET_ROOT/adapters/pi" ;;
esac

cleanup_empty_dir "$TARGET_ROOT"

echo "Done."
