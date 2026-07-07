#!/usr/bin/env bash
set -euo pipefail

ACTION="install"
TARGET="opencode"
CLAUDE_MD=""
CLAUDE_MODE_SET=0
OPENCODE_MODE_SET=0
COPILOT_MODE_SET=0
PI_MODE_SET=0
SKIP_SKILLS=0
PROJECT_SKILLS=0
SKILLS_SOURCE="https://github.com/sprngr/rubber-duck"
SKILLS_CLI="skills@^1.5.14" # pinned npx CLI package spec
SOURCE_MODE="auto" # auto|local|web
RAW_BASE="https://raw.githubusercontent.com/sprngr/rubber-duck/main"
DRY_RUN=0

SCRIPT_PATH="${0:-}"
if [[ -z "${SCRIPT_PATH}" || "${SCRIPT_PATH}" == "-" || "${SCRIPT_PATH}" == "bash" || "${SCRIPT_PATH}" == "sh" ]]; then
  SCRIPT_DIR="$(pwd)"
else
  SCRIPT_DIR="$(cd -- "$(dirname -- "${SCRIPT_PATH}")" && pwd)"
fi

REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." 2>/dev/null && pwd || pwd)"
LOCAL_AGENTS_DIR=""
LOCAL_POLICY_FILE=""
LOCAL_POLICY_AGENTS_FILE=""
REMOTE_AGENTS_PATH=""
REMOTE_POLICY_PATH=""
REMOTE_POLICY_AGENTS_PATH=""
POLICY_MODE="managed_block" # managed_block|file

MANAGED_START="<!-- RUBBER_DUCK_MANAGED_BLOCK START -->"
MANAGED_END="<!-- RUBBER_DUCK_MANAGED_BLOCK END -->"

OPENCODE_AGENTS_DIR="${HOME}/.config/opencode/agents"
OPENCODE_AGENTS_MD="${HOME}/.config/opencode/AGENTS.md"
OPENCODE_PROJECT_AGENTS_DIR=".opencode/agents"
OPENCODE_PROJECT_AGENTS_MD="AGENTS.md"
COPILOT_AGENTS_DIR="${HOME}/.copilot/agents"
COPILOT_AGENTS_MD="${HOME}/.copilot/AGENTS.md"
COPILOT_PROJECT_AGENTS_DIR=".github/agents"
COPILOT_PROJECT_AGENTS_MD="AGENTS.md"
CLAUDE_AGENTS_DIR="${HOME}/.claude/agents"
CLAUDE_POLICY_MD="${HOME}/.claude/CLAUDE.md"
CLAUDE_PROJECT_AGENTS_DIR=".claude/agents"
CLAUDE_PROJECT_POLICY_MD="CLAUDE.md"
PI_AGENTS_DIR="${HOME}/.pi/agent/agents"
PI_AGENTS_MD="${HOME}/.pi/agent/AGENTS.md"
PI_PROJECT_AGENTS_DIR=".pi/agents"
PI_PROJECT_AGENTS_MD="AGENTS.md"

AGENT_FILES=(
  "rubber-duck.md"
  "duck-simple.md"
  "duck-reviewer.md"
  "duck-investigator.md"
  "duck-dry.md"
  "duck-builder.md"
  "duck-adversary.md"
)

REQUIRED_SKILLS=(
  "duck-debt"
  "duck-debug"
  "duck-design"
  "duck-explain"
  "duck-review"
  "duck-teach"
  "duck-triage"
)

# Pi harness compatibility policy (PR1 core; integration in PR2).
# Rows:
# R1 known + subagent pass + tools pass + permissions present => supported (0)
# R2 known + subagent pass + tools pass + permissions missing => supported_with_note (0)
# R3 known + subagent pass + tools missing => incompatible_missing_tools (2)
# R4 known + subagent fail => incompatible_subagent_probe_failed (2)
# R5 unknown + capability pass => unsupported_but_compatible (0)
# R6 unknown + capability fail => unsupported_and_incompatible (2)
# R7 no plugin detected => no_compatible_plugin (2)
# R8 probe infrastructure failure => environment_probe_failed (3)
PI_REQUIRED_TOOLS=("read" "bash" "edit" "write" "grep" "find" "ls")
PI_STATUS_SUPPORTED="supported"
PI_STATUS_SUPPORTED_WITH_NOTE="supported_with_note"
PI_STATUS_INCOMPATIBLE_MISSING_TOOLS="incompatible_missing_tools"
PI_STATUS_INCOMPATIBLE_SUBAGENT_PROBE_FAILED="incompatible_subagent_probe_failed"
PI_STATUS_UNSUPPORTED_BUT_COMPATIBLE="unsupported_but_compatible"
PI_STATUS_UNSUPPORTED_AND_INCOMPATIBLE="unsupported_and_incompatible"
PI_STATUS_NO_COMPATIBLE_PLUGIN="no_compatible_plugin"
PI_STATUS_ENVIRONMENT_PROBE_FAILED="environment_probe_failed"

# Decision inputs (all as strings for portability in shell code):
#   plugin_kind: known|unknown|none
#   subagents_ok: 1|0
#   missing_tools_csv: comma-separated list (empty means none missing)
#   permissions_detected: 1|0
#   probe_error: non-empty means infrastructure/probe execution failure
# Outputs (globals):
#   PI_POLICY_STATUS, PI_POLICY_EXIT_CODE
pi_policy_decide() {
  local plugin_kind="$1"
  local subagents_ok="$2"
  local missing_tools_csv="$3"
  local permissions_detected="$4"
  local probe_error="$5"

  PI_POLICY_STATUS=""
  PI_POLICY_EXIT_CODE=2

  # R8
  if [[ -n "${probe_error}" ]]; then
    PI_POLICY_STATUS="${PI_STATUS_ENVIRONMENT_PROBE_FAILED}"
    PI_POLICY_EXIT_CODE=3
    return 0
  fi

  # R7
  if [[ "${plugin_kind}" == "none" ]]; then
    PI_POLICY_STATUS="${PI_STATUS_NO_COMPATIBLE_PLUGIN}"
    PI_POLICY_EXIT_CODE=2
    return 0
  fi

  # R4 / R6 (capability fail path)
  if [[ "${subagents_ok}" != "1" ]]; then
    if [[ "${plugin_kind}" == "known" ]]; then
      PI_POLICY_STATUS="${PI_STATUS_INCOMPATIBLE_SUBAGENT_PROBE_FAILED}"
    else
      PI_POLICY_STATUS="${PI_STATUS_UNSUPPORTED_AND_INCOMPATIBLE}"
    fi
    PI_POLICY_EXIT_CODE=2
    return 0
  fi

  # R3 (known partial due to missing tools)
  if [[ "${plugin_kind}" == "known" && -n "${missing_tools_csv}" ]]; then
    PI_POLICY_STATUS="${PI_STATUS_INCOMPATIBLE_MISSING_TOOLS}"
    PI_POLICY_EXIT_CODE=2
    return 0
  fi

  # R1 / R2
  if [[ "${plugin_kind}" == "known" ]]; then
    if [[ "${permissions_detected}" == "1" ]]; then
      PI_POLICY_STATUS="${PI_STATUS_SUPPORTED}"
    else
      PI_POLICY_STATUS="${PI_STATUS_SUPPORTED_WITH_NOTE}"
    fi
    PI_POLICY_EXIT_CODE=0
    return 0
  fi

  # R5 (unknown + capabilities pass). Missing tools already handled in probe path.
  PI_POLICY_STATUS="${PI_STATUS_UNSUPPORTED_BUT_COMPATIBLE}"
  PI_POLICY_EXIT_CODE=0
  return 0
}

pi_policy_message() {
  local status="$1"
  local plugin_id="$2"
  local version="$3"
  local missing_csv="$4"
  local probe_error="$5"

  case "${status}" in
    "${PI_STATUS_SUPPORTED}")
      printf 'Pi coding harness enabled (supported plugin: %s@%s).\n' "${plugin_id}" "${version}"
      ;;
    "${PI_STATUS_SUPPORTED_WITH_NOTE}")
      printf 'Pi coding harness enabled (supported plugin: %s@%s). Note: permission plugin not detected; tool-governance UX may be reduced.\n' "${plugin_id}" "${version}"
      ;;
    "${PI_STATUS_UNSUPPORTED_BUT_COMPATIBLE}")
      printf 'Pi coding harness enabled (plugin: %s@%s). Note: this plugin is currently unsupported by policy; capability checks passed.\n' "${plugin_id}" "${version}"
      ;;
    "${PI_STATUS_NO_COMPATIBLE_PLUGIN}")
      printf 'Cannot enable Pi coding harness: no compatible subagent plugin detected. Install one of: pi-subagents, @tintinweb/pi-subagents, @gotgenes/pi-subagents.\n'
      ;;
    "${PI_STATUS_INCOMPATIBLE_SUBAGENT_PROBE_FAILED}")
      printf 'Cannot enable Pi coding harness: detected plugin %s@%s, but subagent capability probe failed.\n' "${plugin_id}" "${version}"
      ;;
    "${PI_STATUS_INCOMPATIBLE_MISSING_TOOLS}")
      printf 'Cannot enable Pi coding harness: missing required tools: %s. Required: read, bash, edit, write, grep, find, ls.\n' "${missing_csv}"
      ;;
    "${PI_STATUS_UNSUPPORTED_AND_INCOMPATIBLE}")
      printf 'Cannot enable Pi coding harness: detected unsupported plugin %s@%s, and compatibility probes failed.\n' "${plugin_id}" "${version}"
      ;;
    "${PI_STATUS_ENVIRONMENT_PROBE_FAILED}")
      printf 'Cannot enable Pi coding harness: unable to run plugin/capability probes in this environment (%s).\n' "${probe_error}"
      ;;
    *)
      printf 'Cannot enable Pi coding harness: internal policy status not recognized (%s).\n' "${status}"
      ;;
  esac
}

usage() {
  cat <<'EOF'
Usage:
  scripts/rubber-duck.sh [install|uninstall|status|doctor|policy-test] [options]

Options:
  --opencode                        Use global opencode paths (~/.config/opencode/agents + ~/config/opencode/AGENTS.md)
  --opencode-project                Use project opencode paths (.opencode/agents + AGENTS.md)
  --copilot                         Use global Copilot paths (~/.copilot/agents + ~/.copilot/AGENTS.md)
  --copilot-project                 Use project Copilot paths (.github/agents + AGENTS.md)
  --pi                              Use global Pi paths (~/.pi/agent/agents + ~/.pi/agent/AGENTS.md)
  --pi-project                      Use project Pi paths (.pi/agents + AGENTS.md)
  --claude                          Use global Claude paths (~/.claude/agents + ~/.claude/CLAUDE.md)
  --claude-project                  Use project Claude paths (.claude/agents + CLAUDE.md)
  --claude-md <path>                Claude target memory file path override
  --skip-skills                     Skip npx skills add/remove/list
  --project-skills                  Install skills to project scope (default is global via -g)
  --skills-source <url-or-path>     Skills package source
  --source <auto|local|web>         Artifact source (default: auto)
  --raw-base <url>                  Raw GitHub base for web source
  --dry-run                         Print planned actions only
  -h, --help                        Show help

Examples:
  scripts/rubber-duck.sh install --opencode
  scripts/rubber-duck.sh install --opencode-project
  scripts/rubber-duck.sh install --copilot
  scripts/rubber-duck.sh install --copilot-project
  scripts/rubber-duck.sh install --pi
  scripts/rubber-duck.sh install --pi-project
  scripts/rubber-duck.sh install --claude
  scripts/rubber-duck.sh install --claude-project
  curl -fsSL https://raw.githubusercontent.com/sprngr/rubber-duck/main/scripts/rubber-duck.sh | bash -s -- install --opencode
EOF
}

log() { printf '%s\n' "$*"; }
warn() { printf 'WARN: %s\n' "$*"; }
err() { printf 'ERROR: %s\n' "$*" >&2; }
timestamp() { date +%Y%m%d-%H%M%S; }

if [[ $# -gt 0 ]]; then
  case "$1" in
    install|uninstall|status|doctor|policy-test)
      ACTION="$1"
      shift
      ;;
  esac
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --opencode)
      if (( OPENCODE_MODE_SET == 1 )) && [[ "${TARGET}" != "opencode" ]]; then
        err "cannot combine --opencode and --opencode-project"
        exit 1
      fi
      TARGET="opencode"
      OPENCODE_MODE_SET=1
      shift
      ;;
    --opencode-project)
      if (( OPENCODE_MODE_SET == 1 )) && [[ "${TARGET}" != "opencode-project" ]]; then
        err "cannot combine --opencode and --opencode-project"
        exit 1
      fi
      TARGET="opencode-project"
      OPENCODE_MODE_SET=1
      shift
      ;;
    --copilot)
      if (( COPILOT_MODE_SET == 1 )) && [[ "${TARGET}" != "copilot" ]]; then
        err "cannot combine --copilot and --copilot-project"
        exit 1
      fi
      TARGET="copilot"
      COPILOT_MODE_SET=1
      shift
      ;;
    --copilot-project)
      if (( COPILOT_MODE_SET == 1 )) && [[ "${TARGET}" != "copilot-project" ]]; then
        err "cannot combine --copilot and --copilot-project"
        exit 1
      fi
      TARGET="copilot-project"
      COPILOT_MODE_SET=1
      shift
      ;;
    --pi)
      if (( PI_MODE_SET == 1 )) && [[ "${TARGET}" != "pi" ]]; then
        err "cannot combine --pi and --pi-project"
        exit 1
      fi
      TARGET="pi"
      PI_MODE_SET=1
      shift
      ;;
    --pi-project)
      if (( PI_MODE_SET == 1 )) && [[ "${TARGET}" != "pi-project" ]]; then
        err "cannot combine --pi and --pi-project"
        exit 1
      fi
      TARGET="pi-project"
      PI_MODE_SET=1
      shift
      ;;
    --claude)
      if (( CLAUDE_MODE_SET == 1 )) && [[ "${TARGET}" != "claude" ]]; then
        err "cannot combine --claude and --claude-project"
        exit 1
      fi
      TARGET="claude"
      CLAUDE_MODE_SET=1
      shift
      ;;
    --claude-project)
      if (( CLAUDE_MODE_SET == 1 )) && [[ "${TARGET}" != "claude-project" ]]; then
        err "cannot combine --claude and --claude-project"
        exit 1
      fi
      TARGET="claude-project"
      CLAUDE_MODE_SET=1
      shift
      ;;
    --claude-md)
      CLAUDE_MD="${2:-}"
      shift 2
      ;;
    --skip-skills)
      SKIP_SKILLS=1
      shift
      ;;
    --project-skills)
      PROJECT_SKILLS=1
      shift
      ;;
    --skills-source)
      SKILLS_SOURCE="${2:-}"
      shift 2
      ;;
    --source)
      SOURCE_MODE="${2:-}"
      shift 2
      ;;
    --raw-base)
      RAW_BASE="${2:-}"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      err "unknown argument: $1"
      usage
      exit 1
      ;;
  esac
done

if [[ -n "${CLAUDE_MD}" && "${TARGET}" != "claude" && "${TARGET}" != "claude-project" ]]; then
  err "--claude-md requires --claude or --claude-project"
  exit 1
fi

resolve_target() {
  case "${TARGET}" in
    opencode)
      DEST_AGENTS_DIR="${OPENCODE_AGENTS_DIR}"
      DEST_POLICY_MD="${OPENCODE_AGENTS_MD}"
      POLICY_MODE="managed_block"
      LOCAL_POLICY_FILE="${REPO_ROOT}/AGENTS.md"
      if [[ -d "${REPO_ROOT}/dist/opencode/agents" ]]; then
        LOCAL_AGENTS_DIR="${REPO_ROOT}/dist/opencode/agents"
      else
        LOCAL_AGENTS_DIR="${REPO_ROOT}/agents"
      fi
      REMOTE_POLICY_PATH="AGENTS.md"
      REMOTE_AGENTS_PATH="dist/opencode/agents"
      ;;
    opencode-project)
      DEST_AGENTS_DIR="${OPENCODE_PROJECT_AGENTS_DIR}"
      DEST_POLICY_MD="${OPENCODE_PROJECT_AGENTS_MD}"
      POLICY_MODE="managed_block"
      LOCAL_POLICY_FILE="${REPO_ROOT}/AGENTS.md"
      if [[ -d "${REPO_ROOT}/dist/opencode/agents" ]]; then
        LOCAL_AGENTS_DIR="${REPO_ROOT}/dist/opencode/agents"
      else
        LOCAL_AGENTS_DIR="${REPO_ROOT}/agents"
      fi
      REMOTE_POLICY_PATH="AGENTS.md"
      REMOTE_AGENTS_PATH="dist/opencode/agents"
      ;;
    copilot)
      DEST_AGENTS_DIR="${COPILOT_AGENTS_DIR}"
      DEST_POLICY_MD="${COPILOT_AGENTS_MD}"
      POLICY_MODE="managed_block"
      LOCAL_POLICY_FILE="${REPO_ROOT}/AGENTS.md"
      if [[ -d "${REPO_ROOT}/dist/copilot/agents" ]]; then
        LOCAL_AGENTS_DIR="${REPO_ROOT}/dist/copilot/agents"
      else
        LOCAL_AGENTS_DIR="${REPO_ROOT}/agents"
      fi
      REMOTE_POLICY_PATH="AGENTS.md"
      REMOTE_AGENTS_PATH="dist/copilot/agents"
      ;;
    copilot-project)
      DEST_AGENTS_DIR="${COPILOT_PROJECT_AGENTS_DIR}"
      DEST_POLICY_MD="${COPILOT_PROJECT_AGENTS_MD}"
      POLICY_MODE="managed_block"
      LOCAL_POLICY_FILE="${REPO_ROOT}/AGENTS.md"
      if [[ -d "${REPO_ROOT}/dist/copilot/agents" ]]; then
        LOCAL_AGENTS_DIR="${REPO_ROOT}/dist/copilot/agents"
      else
        LOCAL_AGENTS_DIR="${REPO_ROOT}/agents"
      fi
      REMOTE_POLICY_PATH="AGENTS.md"
      REMOTE_AGENTS_PATH="dist/copilot/agents"
      ;;
    pi)
      DEST_AGENTS_DIR="${PI_AGENTS_DIR}"
      DEST_POLICY_MD="${PI_AGENTS_MD}"
      POLICY_MODE="managed_block"
      LOCAL_POLICY_FILE="${REPO_ROOT}/AGENTS.md"
      if [[ -d "${REPO_ROOT}/dist/pi/agents" ]]; then
        LOCAL_AGENTS_DIR="${REPO_ROOT}/dist/pi/agents"
      elif [[ -d "${REPO_ROOT}/dist/opencode/agents" ]]; then
        LOCAL_AGENTS_DIR="${REPO_ROOT}/dist/opencode/agents"
      else
        LOCAL_AGENTS_DIR="${REPO_ROOT}/agents"
      fi
      REMOTE_POLICY_PATH="AGENTS.md"
      if [[ -d "${REPO_ROOT}/dist/pi/agents" ]]; then
        REMOTE_AGENTS_PATH="dist/pi/agents"
      else
        REMOTE_AGENTS_PATH="dist/opencode/agents"
      fi
      ;;
    pi-project)
      DEST_AGENTS_DIR="${PI_PROJECT_AGENTS_DIR}"
      DEST_POLICY_MD="${PI_PROJECT_AGENTS_MD}"
      POLICY_MODE="managed_block"
      LOCAL_POLICY_FILE="${REPO_ROOT}/AGENTS.md"
      if [[ -d "${REPO_ROOT}/dist/pi/agents" ]]; then
        LOCAL_AGENTS_DIR="${REPO_ROOT}/dist/pi/agents"
      elif [[ -d "${REPO_ROOT}/dist/opencode/agents" ]]; then
        LOCAL_AGENTS_DIR="${REPO_ROOT}/dist/opencode/agents"
      else
        LOCAL_AGENTS_DIR="${REPO_ROOT}/agents"
      fi
      REMOTE_POLICY_PATH="AGENTS.md"
      if [[ -d "${REPO_ROOT}/dist/pi/agents" ]]; then
        REMOTE_AGENTS_PATH="dist/pi/agents"
      else
        REMOTE_AGENTS_PATH="dist/opencode/agents"
      fi
      ;;
    claude)
      DEST_AGENTS_DIR="${CLAUDE_AGENTS_DIR}"
      DEST_POLICY_MD="${CLAUDE_MD:-${CLAUDE_POLICY_MD}}"
      DEST_CLAUDE_AGENTS_MD="$(dirname -- "${DEST_POLICY_MD}")/AGENTS.md"
      POLICY_MODE="file"
      LOCAL_POLICY_FILE="${REPO_ROOT}/dist/claude/CLAUDE.md"
      LOCAL_POLICY_AGENTS_FILE="${REPO_ROOT}/AGENTS.md"
      LOCAL_AGENTS_DIR="${REPO_ROOT}/dist/claude/agents"
      REMOTE_POLICY_PATH="dist/claude/CLAUDE.md"
      REMOTE_POLICY_AGENTS_PATH="AGENTS.md"
      REMOTE_AGENTS_PATH="dist/claude/agents"
      ;;
    claude-project)
      DEST_AGENTS_DIR="${CLAUDE_PROJECT_AGENTS_DIR}"
      DEST_POLICY_MD="${CLAUDE_MD:-${CLAUDE_PROJECT_POLICY_MD}}"
      DEST_CLAUDE_AGENTS_MD="$(dirname -- "${DEST_POLICY_MD}")/AGENTS.md"
      POLICY_MODE="file"
      LOCAL_POLICY_FILE="${REPO_ROOT}/dist/claude/CLAUDE.md"
      LOCAL_POLICY_AGENTS_FILE="${REPO_ROOT}/AGENTS.md"
      LOCAL_AGENTS_DIR="${REPO_ROOT}/dist/claude/agents"
      REMOTE_POLICY_PATH="dist/claude/CLAUDE.md"
      REMOTE_POLICY_AGENTS_PATH="AGENTS.md"
      REMOTE_AGENTS_PATH="dist/claude/agents"
      ;;
    *)
      err "invalid target: ${TARGET}"
      exit 1
      ;;
  esac
}

pi_target_enabled() {
  [[ "${TARGET}" == "pi" || "${TARGET}" == "pi-project" ]]
}

csv_contains_tool() {
  local csv="$1"
  local needle="$2"
  local item
  IFS=',' read -r -a __csv_items <<< "${csv}"
  for item in "${__csv_items[@]}"; do
    [[ "${item}" == "${needle}" ]] && return 0
  done
  return 1
}

join_by_comma() {
  local out=""
  local part
  for part in "$@"; do
    if [[ -z "${out}" ]]; then
      out="${part}"
    else
      out="${out},${part}"
    fi
  done
  printf '%s' "${out}"
}

pi_clean_token() {
  local token="$1"
  token="${token//,/}"
  token="${token//;/}"
  token="${token//(/}"
  token="${token//)/}"
  token="${token//[/}"
  token="${token//]/}"
  token="${token//\"/}"
  token="${token//\'/}"
  printf '%s' "${token}"
}

pi_extract_plugin_version_from_list() {
  local pi_list="$1"
  local plugin_id="$2"
  local raw token

  for raw in ${pi_list}; do
    token="$(pi_clean_token "${raw}")"
    if [[ "${token}" == "${plugin_id}"@* ]]; then
      printf '%s' "${token##*@}"
      return 0
    fi
  done

  printf 'unknown'
  return 0
}

pi_detect_unknown_subagent_token() {
  local pi_list="$1"
  local match=""

  match="$(printf '%s\n' "${pi_list}" \
    | grep -Eoi '@[[:alnum:]._-]+/[[:alnum:]._-]*subagents[[:alnum:]._-]*(@[0-9][^[:space:]]*)?|[[:alnum:]._-]*subagents[[:alnum:]._-]*(@[0-9][^[:space:]]*)?' \
    | grep -Evi 'worktree|permission' \
    | head -n 1 || true)"

  printf '%s' "${match}"
}

pi_policy_gate() {
  local pi_list=""
  local plugin_kind="none"
  local plugin_id=""
  local plugin_version="unknown"
  local subagents_ok="0"
  local permissions_detected="0"
  local probe_error=""
  local tools_output=""
  local tools_csv=""
  local unknown_token=""
  local missing_tools=()
  local missing_csv=""
  local required_tool
  local message=""
  local subagent_probe_cmd="${PI_SUBAGENT_PROBE_CMD:-pi subagent --help}"
  local tools_probe_cmd="${PI_TOOLS_PROBE_CMD:-pi tools list}"

  if (( DRY_RUN == 1 )); then
    log "[dry-run] skipping Pi capability probes"
    return 0
  fi

  if ! pi_list="$(pi list 2>/dev/null)"; then
    probe_error="pi list failed"
  fi

  if [[ -z "${probe_error}" ]]; then
    if printf '%s' "${pi_list}" | grep -Fq '@gotgenes/pi-subagents'; then
      plugin_kind="known"
      plugin_id='@gotgenes/pi-subagents'
    elif printf '%s' "${pi_list}" | grep -Fq '@tintinweb/pi-subagents'; then
      plugin_kind="known"
      plugin_id='@tintinweb/pi-subagents'
    elif printf '%s' "${pi_list}" | grep -Fq 'pi-subagents'; then
      plugin_kind="known"
      plugin_id='pi-subagents'
    elif printf '%s' "${pi_list}" | grep -qi 'subagents'; then
      plugin_kind="unknown"
      unknown_token="$(pi_detect_unknown_subagent_token "${pi_list}")"
      if [[ -n "${unknown_token}" ]]; then
        if [[ "${unknown_token}" == *@[0-9]* ]]; then
          plugin_id="${unknown_token%@*}"
          plugin_version="${unknown_token##*@}"
        else
          plugin_id="${unknown_token}"
        fi
      else
        plugin_id='unknown-subagents-plugin'
      fi
    else
      plugin_kind="none"
    fi

    if printf '%s' "${pi_list}" | grep -qi 'pi-permission-system'; then
      permissions_detected="1"
    fi

    if [[ -n "${plugin_id}" && "${plugin_version}" == "unknown" ]]; then
      plugin_version="$(pi_extract_plugin_version_from_list "${pi_list}" "${plugin_id}")"
    fi
  fi

  if [[ -z "${probe_error}" && "${plugin_kind}" != "none" ]]; then
    if bash -lc "${subagent_probe_cmd}" >/dev/null 2>&1; then
      subagents_ok="1"
    fi

    if tools_output="$(bash -lc "${tools_probe_cmd}" 2>/dev/null)"; then
      local candidate
      local tools_lower
      tools_lower="$(printf '%s' "${tools_output}" | tr '[:upper:]' '[:lower:]')"
      for candidate in ${PI_REQUIRED_TOOLS[*]}; do
        if printf '%s' "${tools_lower}" | grep -Eq "(^|[^a-z0-9_-])${candidate}([^a-z0-9_-]|$)"; then
          if [[ -z "${tools_csv}" ]]; then
            tools_csv="${candidate}"
          else
            tools_csv="${tools_csv},${candidate}"
          fi
        fi
      done
    fi
  fi

  if [[ "${subagents_ok}" == "1" ]]; then
    for required_tool in "${PI_REQUIRED_TOOLS[@]}"; do
      if ! csv_contains_tool "${tools_csv}" "${required_tool}"; then
        missing_tools+=("${required_tool}")
      fi
    done
  fi

  if (( ${#missing_tools[@]} > 0 )); then
    missing_csv="$(join_by_comma "${missing_tools[@]}")"
  fi

  pi_policy_decide "${plugin_kind}" "${subagents_ok}" "${missing_csv}" "${permissions_detected}" "${probe_error}"
  message="$(pi_policy_message "${PI_POLICY_STATUS}" "${plugin_id}" "${plugin_version}" "${missing_csv}" "${probe_error}")"

  if (( PI_POLICY_EXIT_CODE == 0 )); then
    if [[ "${PI_POLICY_STATUS}" == "${PI_STATUS_SUPPORTED_WITH_NOTE}" || "${PI_POLICY_STATUS}" == "${PI_STATUS_UNSUPPORTED_BUT_COMPATIBLE}" ]]; then
      warn "${message}"
    else
      log "${message}"
    fi
    return 0
  fi

  err "${message}"
  return "${PI_POLICY_EXIT_CODE}"
}

running_piped() {
  [[ "${0:-}" == "bash" || "${0:-}" == "sh" || "${0:-}" == "-" ]]
}

has_local_sources() {
  [[ -f "${LOCAL_POLICY_FILE}" ]] || return 1
  if [[ "${POLICY_MODE}" == "file" ]]; then
    [[ -f "${LOCAL_POLICY_AGENTS_FILE}" ]] || return 1
  fi
  for f in "${AGENT_FILES[@]}"; do
    [[ -f "${LOCAL_AGENTS_DIR}/${f}" ]] || return 1
  done
  return 0
}

choose_source() {
  case "${SOURCE_MODE}" in
    auto)
      if running_piped; then
        EFFECTIVE_SOURCE="web"
      elif has_local_sources; then
        EFFECTIVE_SOURCE="local"
      else
        EFFECTIVE_SOURCE="web"
      fi
      ;;
    local|web)
      EFFECTIVE_SOURCE="${SOURCE_MODE}"
      ;;
    *)
      err "invalid --source value: ${SOURCE_MODE}"
      exit 1
      ;;
  esac
}

require_cmd() {
  local cmd="$1"
  command -v "${cmd}" >/dev/null 2>&1 || { err "required command missing: ${cmd}"; exit 1; }
}

prepare_sources() {
  TMP_DIR="$(mktemp -d)"
  trap 'rm -rf "${TMP_DIR}"' EXIT

  if [[ "${EFFECTIVE_SOURCE}" == "local" ]]; then
    if ! has_local_sources; then
      err "local source selected but repo artifacts not found. Use --source web or run from repo checkout."
      exit 1
    fi
    if [[ "${POLICY_MODE}" == "managed_block" ]]; then
      cp -f "${LOCAL_POLICY_FILE}" "${TMP_DIR}/AGENTS.md"
    else
      cp -f "${LOCAL_POLICY_FILE}" "${TMP_DIR}/CLAUDE.md"
      cp -f "${LOCAL_POLICY_AGENTS_FILE}" "${TMP_DIR}/AGENTS.md"
    fi
    for f in "${AGENT_FILES[@]}"; do
      cp -f "${LOCAL_AGENTS_DIR}/${f}" "${TMP_DIR}/${f}"
    done
    log "source: local (${REPO_ROOT})"
    return
  fi

  require_cmd curl
  if [[ "${POLICY_MODE}" == "managed_block" ]]; then
    curl -fsSL "${RAW_BASE}/${REMOTE_POLICY_PATH}" -o "${TMP_DIR}/AGENTS.md"
  else
    curl -fsSL "${RAW_BASE}/${REMOTE_POLICY_PATH}" -o "${TMP_DIR}/CLAUDE.md"
    curl -fsSL "${RAW_BASE}/${REMOTE_POLICY_AGENTS_PATH}" -o "${TMP_DIR}/AGENTS.md"
  fi
  for f in "${AGENT_FILES[@]}"; do
    curl -fsSL "${RAW_BASE}/${REMOTE_AGENTS_PATH}/${f}" -o "${TMP_DIR}/${f}"
  done
  log "source: web (${RAW_BASE})"
}

strip_managed_block_to_file() {
  local src="$1"
  local out="$2"
  if [[ ! -f "${src}" ]]; then
    : > "${out}"
    return 0
  fi
  awk -v start="${MANAGED_START}" -v end="${MANAGED_END}" '
    $0 == start {in_block=1; next}
    $0 == end {in_block=0; next}
    !in_block {print}
  ' "${src}" > "${out}"
}

strip_managed_block() {
  local target="$1"
  local tmp
  tmp="$(mktemp)"
  strip_managed_block_to_file "${target}" "${tmp}"
  mv "${tmp}" "${target}"
}

backup_md() {
  local target="$1"
  local backup
  backup="${target}.bak.$(timestamp)"
  if (( DRY_RUN == 1 )); then
    log "[dry-run] backup ${target} -> ${backup}"
    return
  fi
  mkdir -p "$(dirname -- "${target}")"
  if [[ -f "${target}" ]]; then
    cp -f "${target}" "${backup}"
  else
    : > "${backup}"
  fi
  log "Backup created: ${backup}"
}

upsert_managed_block() {
  local target="${1:-${DEST_POLICY_MD}}"
  local content_file="${2:-${TMP_DIR}/AGENTS.md}"
  if (( DRY_RUN == 1 )); then
    log "[dry-run] upsert managed block in ${target}"
    return
  fi
  mkdir -p "$(dirname -- "${target}")"
  touch "${target}"
  strip_managed_block "${target}"
  {
    printf '\n%s\n' "${MANAGED_START}"
    cat "${content_file}"
    printf '%s\n' "${MANAGED_END}"
  } >> "${target}"
}

remove_managed_block() {
  local target="${1:-${DEST_POLICY_MD}}"
  if (( DRY_RUN == 1 )); then
    log "[dry-run] remove managed block from ${target}"
    return
  fi
  [[ -f "${target}" ]] || return 0
  strip_managed_block "${target}"
}

install_policy_file() {
  # Claude targets keep a two-file layout (CLAUDE.md -> @AGENTS.md include,
  # AGENTS.md -> policy). Upsert managed blocks into both so user-authored
  # content in either file is preserved instead of clobbered.
  upsert_managed_block "${DEST_CLAUDE_AGENTS_MD}" "${TMP_DIR}/AGENTS.md"
  upsert_managed_block "${DEST_POLICY_MD}" "${TMP_DIR}/CLAUDE.md"
  if (( DRY_RUN == 0 )); then
    log "Installed policy block -> ${DEST_POLICY_MD}"
    log "Installed policy block -> ${DEST_CLAUDE_AGENTS_MD}"
  fi
}

remove_policy_file() {
  # Strip only our managed blocks; user content in these files is left intact.
  remove_managed_block "${DEST_POLICY_MD}"
  remove_managed_block "${DEST_CLAUDE_AGENTS_MD}"
  if (( DRY_RUN == 0 )); then
    log "Removed policy block from ${DEST_POLICY_MD}"
    log "Removed policy block from ${DEST_CLAUDE_AGENTS_MD}"
  fi
}

install_agents() {
  if (( DRY_RUN == 1 )); then
    log "[dry-run] ensure dir ${DEST_AGENTS_DIR}"
    for f in "${AGENT_FILES[@]}"; do
      log "[dry-run] cp ${TMP_DIR}/${f} -> ${DEST_AGENTS_DIR}/${f}"
    done
    return
  fi
  mkdir -p "${DEST_AGENTS_DIR}"
  for f in "${AGENT_FILES[@]}"; do
    cp -f "${TMP_DIR}/${f}" "${DEST_AGENTS_DIR}/${f}"
  done
  log "Installed ${#AGENT_FILES[@]} agents -> ${DEST_AGENTS_DIR}"
}

uninstall_agents() {
  if (( DRY_RUN == 1 )); then
    for f in "${AGENT_FILES[@]}"; do
      log "[dry-run] rm ${DEST_AGENTS_DIR}/${f}"
    done
    return
  fi
  local removed=0
  for f in "${AGENT_FILES[@]}"; do
    if [[ -f "${DEST_AGENTS_DIR}/${f}" ]]; then
      rm -f "${DEST_AGENTS_DIR}/${f}"
      removed=$((removed + 1))
    fi
  done
  log "Removed ${removed} agents from ${DEST_AGENTS_DIR}"
}

skills_install() {
  (( SKIP_SKILLS == 1 )) && return 0
  local scope=""
  (( PROJECT_SKILLS == 0 )) && scope="-g"
  if (( DRY_RUN == 1 )); then
    log "[dry-run] npx --yes ${SKILLS_CLI} add ${SKILLS_SOURCE} --skill ${REQUIRED_SKILLS[*]} ${scope}"
    return
  fi
  if ! command -v npx >/dev/null 2>&1; then
    warn "npx not found; skipping skills install"
    return
  fi
  npx --yes "${SKILLS_CLI}" add "${SKILLS_SOURCE}" --skill ${REQUIRED_SKILLS[*]} ${scope}
}

skills_uninstall() {
  (( SKIP_SKILLS == 1 )) && return 0
  local scope=""
  (( PROJECT_SKILLS == 0 )) && scope="-g"
  if (( DRY_RUN == 1 )); then
    log "[dry-run] npx --yes ${SKILLS_CLI} remove ${SKILLS_SOURCE} --skill ${REQUIRED_SKILLS[*]} ${scope}"
    return
  fi
  if ! command -v npx >/dev/null 2>&1; then
    warn "npx not found; skipping skills uninstall"
    return
  fi
  if ! npx --yes "${SKILLS_CLI}" remove "${SKILLS_SOURCE}" --skill ${REQUIRED_SKILLS[*]}  ${scope}; then
    warn "skills remove failed; remove package manually if needed"
  fi
}

skills_status() {
  (( SKIP_SKILLS == 1 )) && { log "skills: skipped (--skip-skills)"; return 0; }
  if ! command -v npx >/dev/null 2>&1; then
    log "skills: npx missing"
    return
  fi
  local list scope=""
  local skill
  local missing=0
  (( PROJECT_SKILLS == 0 )) && scope="-g"
  SKILLS_LIST_CMD=(npx --yes "${SKILLS_CLI}" list ${scope})

  if list="$(NO_COLOR=1 "${SKILLS_LIST_CMD[@]}" </dev/null 2>/dev/null)"; then
    for skill in "${REQUIRED_SKILLS[@]}"; do
      if ! printf '%s' "${list}" | grep -Fq -- "${skill}"; then
        missing=1
        break
      fi
    done
    if (( missing == 0 )); then
      log "skills: installed (${SKILLS_SOURCE})"
    else
      log "skills: not detected (${SKILLS_SOURCE})"
    fi
  else
    log "skills: unable to query (npx skills list failed)"
  fi
}

has_managed_block() {
  local target="${1:-${DEST_POLICY_MD}}"
  [[ -f "${target}" ]] || return 1
  grep -Fq "${MANAGED_START}" "${target}" && grep -Fq "${MANAGED_END}" "${target}"
}

report_policy_block() {
  local target="$1" state="missing"
  has_managed_block "${target}" && state="present"
  log "AGENTS policy block (${target##*/}): ${state}"
}

status() {
  log "target: ${TARGET}"
  log "agents_dir: ${DEST_AGENTS_DIR}"
  log "policy_md: ${DEST_POLICY_MD}"
  local installed=0
  for f in "${AGENT_FILES[@]}"; do
    [[ -f "${DEST_AGENTS_DIR}/${f}" ]] && installed=$((installed + 1))
  done
  log "agents: ${installed}/${#AGENT_FILES[@]} present"
  report_policy_block "${DEST_POLICY_MD}"
  [[ "${POLICY_MODE}" == "file" ]] && report_policy_block "${DEST_CLAUDE_AGENTS_MD}"
  skills_status
}

doctor() {
  require_cmd awk
  require_cmd cp
  if [[ "${EFFECTIVE_SOURCE}" == "web" ]]; then require_cmd curl; fi
  if pi_target_enabled; then require_cmd pi; fi
  if (( DRY_RUN == 1 )); then
    [[ -d "${DEST_AGENTS_DIR}" ]] || warn "doctor: agents dir missing, would create: ${DEST_AGENTS_DIR}"
    [[ -d "$(dirname -- "${DEST_POLICY_MD}")" ]] || warn "doctor: policy parent missing, would create: $(dirname -- "${DEST_POLICY_MD}")"
    if [[ "${POLICY_MODE}" == "file" ]]; then
      [[ -d "$(dirname -- "${DEST_CLAUDE_AGENTS_MD}")" ]] || warn "doctor: policy parent missing, would create: $(dirname -- "${DEST_CLAUDE_AGENTS_MD}")"
    fi
  else
    mkdir -p "${DEST_AGENTS_DIR}"
    mkdir -p "$(dirname -- "${DEST_POLICY_MD}")"
    if [[ "${POLICY_MODE}" == "file" ]]; then
      mkdir -p "$(dirname -- "${DEST_CLAUDE_AGENTS_MD}")"
    fi
  fi
  log "doctor: ok"
}

assert_eq() {
  local got="$1"
  local want="$2"
  local label="$3"
  if [[ "${got}" != "${want}" ]]; then
    err "policy-test failed: ${label} (got='${got}' want='${want}')"
    return 1
  fi
  return 0
}

run_policy_tests() {
  local failures=0
  local msg

  if ! pi_target_enabled; then
    err "policy-test requires a Pi target. Use --pi or --pi-project."
    return 1
  fi

  # R1
  pi_policy_decide "known" "1" "" "1" ""
  assert_eq "${PI_POLICY_STATUS}" "${PI_STATUS_SUPPORTED}" "R1 status" || failures=$((failures + 1))
  assert_eq "${PI_POLICY_EXIT_CODE}" "0" "R1 exit" || failures=$((failures + 1))

  # R2
  pi_policy_decide "known" "1" "" "0" ""
  assert_eq "${PI_POLICY_STATUS}" "${PI_STATUS_SUPPORTED_WITH_NOTE}" "R2 status" || failures=$((failures + 1))
  assert_eq "${PI_POLICY_EXIT_CODE}" "0" "R2 exit" || failures=$((failures + 1))

  # R3
  pi_policy_decide "known" "1" "grep,find" "1" ""
  assert_eq "${PI_POLICY_STATUS}" "${PI_STATUS_INCOMPATIBLE_MISSING_TOOLS}" "R3 status" || failures=$((failures + 1))
  assert_eq "${PI_POLICY_EXIT_CODE}" "2" "R3 exit" || failures=$((failures + 1))

  # R4
  pi_policy_decide "known" "0" "" "1" ""
  assert_eq "${PI_POLICY_STATUS}" "${PI_STATUS_INCOMPATIBLE_SUBAGENT_PROBE_FAILED}" "R4 status" || failures=$((failures + 1))
  assert_eq "${PI_POLICY_EXIT_CODE}" "2" "R4 exit" || failures=$((failures + 1))

  # R5
  pi_policy_decide "unknown" "1" "" "0" ""
  assert_eq "${PI_POLICY_STATUS}" "${PI_STATUS_UNSUPPORTED_BUT_COMPATIBLE}" "R5 status" || failures=$((failures + 1))
  assert_eq "${PI_POLICY_EXIT_CODE}" "0" "R5 exit" || failures=$((failures + 1))

  # R6
  pi_policy_decide "unknown" "0" "" "0" ""
  assert_eq "${PI_POLICY_STATUS}" "${PI_STATUS_UNSUPPORTED_AND_INCOMPATIBLE}" "R6 status" || failures=$((failures + 1))
  assert_eq "${PI_POLICY_EXIT_CODE}" "2" "R6 exit" || failures=$((failures + 1))

  # R7
  pi_policy_decide "none" "0" "" "0" ""
  assert_eq "${PI_POLICY_STATUS}" "${PI_STATUS_NO_COMPATIBLE_PLUGIN}" "R7 status" || failures=$((failures + 1))
  assert_eq "${PI_POLICY_EXIT_CODE}" "2" "R7 exit" || failures=$((failures + 1))

  # R8
  pi_policy_decide "known" "1" "" "1" "pi list unavailable"
  assert_eq "${PI_POLICY_STATUS}" "${PI_STATUS_ENVIRONMENT_PROBE_FAILED}" "R8 status" || failures=$((failures + 1))
  assert_eq "${PI_POLICY_EXIT_CODE}" "3" "R8 exit" || failures=$((failures + 1))

  # Message goldens (exact)
  msg="$(pi_policy_message "${PI_STATUS_SUPPORTED}" "pi-subagents" "1.2.3" "" "")"
  assert_eq "${msg}" "Pi coding harness enabled (supported plugin: pi-subagents@1.2.3)." "msg supported" || failures=$((failures + 1))

  msg="$(pi_policy_message "${PI_STATUS_SUPPORTED_WITH_NOTE}" "pi-subagents" "1.2.3" "" "")"
  assert_eq "${msg}" "Pi coding harness enabled (supported plugin: pi-subagents@1.2.3). Note: permission plugin not detected; tool-governance UX may be reduced." "msg supported_with_note" || failures=$((failures + 1))

  msg="$(pi_policy_message "${PI_STATUS_UNSUPPORTED_BUT_COMPATIBLE}" "custom/subagents" "0.1.0" "" "")"
  assert_eq "${msg}" "Pi coding harness enabled (plugin: custom/subagents@0.1.0). Note: this plugin is currently unsupported by policy; capability checks passed." "msg unsupported_but_compatible" || failures=$((failures + 1))

  msg="$(pi_policy_message "${PI_STATUS_NO_COMPATIBLE_PLUGIN}" "" "" "" "")"
  assert_eq "${msg}" "Cannot enable Pi coding harness: no compatible subagent plugin detected. Install one of: pi-subagents, @tintinweb/pi-subagents, @gotgenes/pi-subagents." "msg no_compatible_plugin" || failures=$((failures + 1))

  msg="$(pi_policy_message "${PI_STATUS_INCOMPATIBLE_SUBAGENT_PROBE_FAILED}" "@tintinweb/pi-subagents" "2.0.0" "" "")"
  assert_eq "${msg}" "Cannot enable Pi coding harness: detected plugin @tintinweb/pi-subagents@2.0.0, but subagent capability probe failed." "msg incompatible_subagent_probe_failed" || failures=$((failures + 1))

  msg="$(pi_policy_message "${PI_STATUS_INCOMPATIBLE_MISSING_TOOLS}" "" "" "read,bash" "")"
  assert_eq "${msg}" "Cannot enable Pi coding harness: missing required tools: read,bash. Required: read, bash, edit, write, grep, find, ls." "msg incompatible_missing_tools" || failures=$((failures + 1))

  msg="$(pi_policy_message "${PI_STATUS_UNSUPPORTED_AND_INCOMPATIBLE}" "custom/subagents" "0.1.0" "" "")"
  assert_eq "${msg}" "Cannot enable Pi coding harness: detected unsupported plugin custom/subagents@0.1.0, and compatibility probes failed." "msg unsupported_and_incompatible" || failures=$((failures + 1))

  msg="$(pi_policy_message "${PI_STATUS_ENVIRONMENT_PROBE_FAILED}" "" "" "" "timeout")"
  assert_eq "${msg}" "Cannot enable Pi coding harness: unable to run plugin/capability probes in this environment (timeout)." "msg environment_probe_failed" || failures=$((failures + 1))

  if (( failures > 0 )); then
    err "policy-test: ${failures} failure(s)"
    return 1
  fi

  log "policy-test: ok (R1-R8 + message goldens)"
  return 0
}

resolve_target
choose_source

case "${ACTION}" in
  install)
    doctor
    if pi_target_enabled; then
      pi_policy_gate
    fi
    prepare_sources
    install_agents
    backup_md "${DEST_POLICY_MD}"
    if [[ "${POLICY_MODE}" == "managed_block" ]]; then
      upsert_managed_block
    else
      backup_md "${DEST_CLAUDE_AGENTS_MD}"
      install_policy_file
    fi
    skills_install
    status
    ;;
  uninstall)
    doctor
    prepare_sources
    uninstall_agents
    backup_md "${DEST_POLICY_MD}"
    if [[ "${POLICY_MODE}" == "managed_block" ]]; then
      remove_managed_block
    else
      backup_md "${DEST_CLAUDE_AGENTS_MD}"
      remove_policy_file
    fi
    skills_uninstall
    status
    ;;
  status)
    status
    ;;
  doctor)
    doctor
    ;;
  policy-test)
    run_policy_tests
    ;;
  *)
    err "unknown action: ${ACTION}"
    usage
    exit 1
    ;;
esac
