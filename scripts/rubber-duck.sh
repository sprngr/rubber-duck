#!/usr/bin/env bash
set -euo pipefail

ACTION="install"
TARGET="generic"
AGENTS_DIR=""
AGENTS_MD=""
CLAUDE_MD=""
CLAUDE_MODE_SET=0
SKIP_SKILLS=0
PROJECT_SKILLS=0
SKILLS_SOURCE="https://github.com/sprngr/rubber-duck"
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
CLAUDE_AGENTS_DIR="${HOME}/.claude/agents"
CLAUDE_POLICY_MD="${HOME}/.claude/CLAUDE.md"
CLAUDE_PROJECT_AGENTS_DIR=".claude/agents"
CLAUDE_PROJECT_POLICY_MD="CLAUDE.md"

OPENCODE_AGENT_FILES=(
  "rubber-duck.agent.md"
  "duck-simple.agent.md"
  "duck-reviewer.agent.md"
  "duck-investigator.agent.md"
  "duck-dry.agent.md"
  "duck-builder.agent.md"
  "duck-adversary.agent.md"
)

CLAUDE_AGENT_FILES=(
  "rubber-duck.md"
  "duck-simple.md"
  "duck-reviewer.md"
  "duck-investigator.md"
  "duck-dry.md"
  "duck-builder.md"
  "duck-adversary.md"
)

AGENT_FILES=()

usage() {
  cat <<'EOF'
Usage:
  scripts/rubber-duck.sh [install|uninstall|status|doctor] [options]

Options:
  --opencode                        Use preconfigured opencode paths
  --claude                          Use global Claude paths (~/.claude/agents + ~/.claude/CLAUDE.md)
  --claude-project                  Use project Claude paths (.claude/agents + CLAUDE.md)
  --agents-dir <path>               Generic target agents dir
  --agents-md <path>                Generic target AGENTS.md path
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
  scripts/rubber-duck.sh install --claude
  scripts/rubber-duck.sh install --claude-project
  scripts/rubber-duck.sh install --agents-dir ~/.h/agents --agents-md ~/.h/AGENTS.md
  curl -fsSL https://raw.githubusercontent.com/sprngr/rubber-duck/main/scripts/rubber-duck.sh | bash -s -- install --opencode
EOF
}

log() { printf '%s\n' "$*"; }
warn() { printf 'WARN: %s\n' "$*"; }
err() { printf 'ERROR: %s\n' "$*" >&2; }
timestamp() { date +%Y%m%d-%H%M%S; }

if [[ $# -gt 0 ]]; then
  case "$1" in
    install|uninstall|status|doctor)
      ACTION="$1"
      shift
      ;;
  esac
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --opencode)
      TARGET="opencode"
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
    --agents-dir)
      TARGET="generic"
      AGENTS_DIR="${2:-}"
      shift 2
      ;;
    --agents-md)
      TARGET="generic"
      AGENTS_MD="${2:-}"
      shift 2
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
      AGENT_FILES=("${OPENCODE_AGENT_FILES[@]}")
      if [[ -f "${REPO_ROOT}/dist/opencode/AGENTS.md" ]]; then
        LOCAL_POLICY_FILE="${REPO_ROOT}/dist/opencode/AGENTS.md"
        LOCAL_AGENTS_DIR="${REPO_ROOT}/dist/opencode/agents"
      else
        LOCAL_POLICY_FILE="${REPO_ROOT}/AGENTS.md"
        LOCAL_AGENTS_DIR="${REPO_ROOT}/agents"
      fi
      REMOTE_POLICY_PATH="dist/opencode/AGENTS.md"
      REMOTE_AGENTS_PATH="dist/opencode/agents"
      ;;
    claude)
      DEST_AGENTS_DIR="${CLAUDE_AGENTS_DIR}"
      DEST_POLICY_MD="${CLAUDE_MD:-${CLAUDE_POLICY_MD}}"
      DEST_CLAUDE_AGENTS_MD="$(dirname -- "${DEST_POLICY_MD}")/AGENTS.md"
      POLICY_MODE="file"
      AGENT_FILES=("${CLAUDE_AGENT_FILES[@]}")
      LOCAL_POLICY_FILE="${REPO_ROOT}/dist/claude/CLAUDE.md"
      LOCAL_POLICY_AGENTS_FILE="${REPO_ROOT}/dist/opencode/AGENTS.md"
      LOCAL_AGENTS_DIR="${REPO_ROOT}/dist/claude/agents"
      REMOTE_POLICY_PATH="dist/claude/CLAUDE.md"
      REMOTE_POLICY_AGENTS_PATH="dist/opencode/AGENTS.md"
      REMOTE_AGENTS_PATH="dist/claude/agents"
      ;;
    claude-project)
      DEST_AGENTS_DIR="${CLAUDE_PROJECT_AGENTS_DIR}"
      DEST_POLICY_MD="${CLAUDE_MD:-${CLAUDE_PROJECT_POLICY_MD}}"
      DEST_CLAUDE_AGENTS_MD="$(dirname -- "${DEST_POLICY_MD}")/AGENTS.md"
      POLICY_MODE="file"
      AGENT_FILES=("${CLAUDE_AGENT_FILES[@]}")
      LOCAL_POLICY_FILE="${REPO_ROOT}/dist/claude/CLAUDE.md"
      LOCAL_POLICY_AGENTS_FILE="${REPO_ROOT}/dist/opencode/AGENTS.md"
      LOCAL_AGENTS_DIR="${REPO_ROOT}/dist/claude/agents"
      REMOTE_POLICY_PATH="dist/claude/CLAUDE.md"
      REMOTE_POLICY_AGENTS_PATH="dist/opencode/AGENTS.md"
      REMOTE_AGENTS_PATH="dist/claude/agents"
      ;;
    generic)
      if [[ -z "${AGENTS_DIR}" || -z "${AGENTS_MD}" ]]; then
        err "generic target requires --agents-dir and --agents-md (or use --opencode)"
        exit 1
      fi
      DEST_AGENTS_DIR="${AGENTS_DIR}"
      DEST_POLICY_MD="${AGENTS_MD}"
      POLICY_MODE="managed_block"
      AGENT_FILES=("${OPENCODE_AGENT_FILES[@]}")
      if [[ -f "${REPO_ROOT}/dist/opencode/AGENTS.md" ]]; then
        LOCAL_POLICY_FILE="${REPO_ROOT}/dist/opencode/AGENTS.md"
        LOCAL_AGENTS_DIR="${REPO_ROOT}/dist/opencode/agents"
      else
        LOCAL_POLICY_FILE="${REPO_ROOT}/AGENTS.md"
        LOCAL_AGENTS_DIR="${REPO_ROOT}/agents"
      fi
      REMOTE_POLICY_PATH="dist/opencode/AGENTS.md"
      REMOTE_AGENTS_PATH="dist/opencode/agents"
      ;;
    *)
      err "invalid target: ${TARGET}"
      exit 1
      ;;
  esac
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

backup_policy_md() {
  local backup
  backup="${DEST_POLICY_MD}.bak.$(timestamp)"
  if (( DRY_RUN == 1 )); then
    log "[dry-run] backup ${DEST_POLICY_MD} -> ${backup}"
    return
  fi
  mkdir -p "$(dirname -- "${DEST_POLICY_MD}")"
  if [[ -f "${DEST_POLICY_MD}" ]]; then
    cp -f "${DEST_POLICY_MD}" "${backup}"
  else
    : > "${backup}"
  fi
  log "Backup created: ${backup}"
}

backup_claude_agents_md() {
  local backup
  backup="${DEST_CLAUDE_AGENTS_MD}.bak.$(timestamp)"
  if (( DRY_RUN == 1 )); then
    log "[dry-run] backup ${DEST_CLAUDE_AGENTS_MD} -> ${backup}"
    return
  fi
  mkdir -p "$(dirname -- "${DEST_CLAUDE_AGENTS_MD}")"
  if [[ -f "${DEST_CLAUDE_AGENTS_MD}" ]]; then
    cp -f "${DEST_CLAUDE_AGENTS_MD}" "${backup}"
  else
    : > "${backup}"
  fi
  log "Backup created: ${backup}"
}

upsert_managed_block() {
  if (( DRY_RUN == 1 )); then
    log "[dry-run] upsert managed block in ${DEST_POLICY_MD}"
    return
  fi
  mkdir -p "$(dirname -- "${DEST_POLICY_MD}")"
  touch "${DEST_POLICY_MD}"
  strip_managed_block "${DEST_POLICY_MD}"
  {
    printf '\n%s\n' "${MANAGED_START}"
    cat "${TMP_DIR}/AGENTS.md"
    printf '%s\n' "${MANAGED_END}"
  } >> "${DEST_POLICY_MD}"
}

remove_managed_block() {
  if (( DRY_RUN == 1 )); then
    log "[dry-run] remove managed block from ${DEST_POLICY_MD}"
    return
  fi
  [[ -f "${DEST_POLICY_MD}" ]] || return 0
  strip_managed_block "${DEST_POLICY_MD}"
}

install_policy_file() {
  if (( DRY_RUN == 1 )); then
    log "[dry-run] cp ${TMP_DIR}/CLAUDE.md -> ${DEST_POLICY_MD}"
    log "[dry-run] cp ${TMP_DIR}/AGENTS.md -> ${DEST_CLAUDE_AGENTS_MD}"
    return
  fi
  mkdir -p "$(dirname -- "${DEST_POLICY_MD}")"
  cp -f "${TMP_DIR}/CLAUDE.md" "${DEST_POLICY_MD}"
  cp -f "${TMP_DIR}/AGENTS.md" "${DEST_CLAUDE_AGENTS_MD}"
  log "Installed policy file -> ${DEST_POLICY_MD}"
  log "Installed policy file -> ${DEST_CLAUDE_AGENTS_MD}"
}

remove_policy_file() {
  local removed=0
  if (( DRY_RUN == 1 )); then
    log "[dry-run] remove ${DEST_POLICY_MD}"
    log "[dry-run] remove ${DEST_CLAUDE_AGENTS_MD}"
    return
  fi

  if [[ -f "${DEST_POLICY_MD}" ]]; then
    if cmp -s "${DEST_POLICY_MD}" "${TMP_DIR}/CLAUDE.md"; then
      rm -f "${DEST_POLICY_MD}"
      log "Removed policy file ${DEST_POLICY_MD}"
      removed=1
    else
      warn "policy file differs from installed artifact; leaving in place: ${DEST_POLICY_MD}"
    fi
  fi

  if [[ -f "${DEST_CLAUDE_AGENTS_MD}" ]]; then
    if cmp -s "${DEST_CLAUDE_AGENTS_MD}" "${TMP_DIR}/AGENTS.md"; then
      rm -f "${DEST_CLAUDE_AGENTS_MD}"
      log "Removed policy file ${DEST_CLAUDE_AGENTS_MD}"
      removed=1
    else
      warn "policy file differs from installed artifact; leaving in place: ${DEST_CLAUDE_AGENTS_MD}"
    fi
  fi

  (( removed == 1 )) || log "No removable policy files matched installed artifacts"
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
  if (( DRY_RUN == 1 )); then
    if (( PROJECT_SKILLS == 1 )); then
      log "[dry-run] npx skills add ${SKILLS_SOURCE} -y"
    else
      log "[dry-run] npx skills add ${SKILLS_SOURCE} -y -g"
    fi
    return
  fi
  if ! command -v npx >/dev/null 2>&1; then
    warn "npx not found; skipping skills install"
    return
  fi
  if (( PROJECT_SKILLS == 1 )); then
    npx skills add "${SKILLS_SOURCE}" -y
  else
    npx skills add "${SKILLS_SOURCE}" -y -g
  fi
}

skills_uninstall() {
  (( SKIP_SKILLS == 1 )) && return 0
  if (( DRY_RUN == 1 )); then
    if (( PROJECT_SKILLS == 1 )); then
      log "[dry-run] npx skills remove ${SKILLS_SOURCE}"
    else
      log "[dry-run] npx skills remove ${SKILLS_SOURCE} -g"
    fi
    return
  fi
  if ! command -v npx >/dev/null 2>&1; then
    warn "npx not found; skipping skills uninstall"
    return
  fi
  if (( PROJECT_SKILLS == 1 )); then
    if ! npx skills remove "${SKILLS_SOURCE}"; then
      warn "skills remove failed; remove package manually if needed"
    fi
  else
    if ! npx skills remove "${SKILLS_SOURCE}" -g; then
      warn "skills remove failed; remove package manually if needed"
    fi
  fi
}

skills_status() {
  (( SKIP_SKILLS == 1 )) && { log "skills: skipped (--skip-skills)"; return 0; }
  if ! command -v npx >/dev/null 2>&1; then
    log "skills: npx missing"
    return
  fi
  local list

  if (( PROJECT_SKILLS == 1 )); then
    SKILLS_LIST_CMD=(npx skills list)
  else
    SKILLS_LIST_CMD=(npx skills list -g)
  fi

  if list="$("${SKILLS_LIST_CMD[@]}" 2>/dev/null)"; then
    if printf '%s' "${list}" | grep -Fq -- "${SKILLS_SOURCE}"; then
      log "skills: installed (${SKILLS_SOURCE})"
    else
      log "skills: not detected (${SKILLS_SOURCE})"
    fi
  else
    log "skills: unable to query (npx skills list failed)"
  fi
}

has_managed_block() {
  [[ -f "${DEST_POLICY_MD}" ]] || return 1
  grep -Fq "${MANAGED_START}" "${DEST_POLICY_MD}" && grep -Fq "${MANAGED_END}" "${DEST_POLICY_MD}"
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
  if [[ "${POLICY_MODE}" == "managed_block" ]]; then
    if has_managed_block; then
      log "AGENTS policy block: present"
    else
      log "AGENTS policy block: missing"
    fi
  else
    if [[ -f "${DEST_POLICY_MD}" ]]; then
      log "CLAUDE.md: present"
    else
      log "CLAUDE.md: missing"
    fi
    if [[ -f "${DEST_CLAUDE_AGENTS_MD}" ]]; then
      log "AGENTS.md: present"
    else
      log "AGENTS.md: missing"
    fi
  fi
  skills_status
}

doctor() {
  require_cmd awk
  require_cmd cp
  if [[ "${EFFECTIVE_SOURCE}" == "web" ]]; then require_cmd curl; fi
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

resolve_target
choose_source

case "${ACTION}" in
  install)
    doctor
    prepare_sources
    install_agents
    backup_policy_md
    if [[ "${POLICY_MODE}" == "managed_block" ]]; then
      upsert_managed_block
    else
      backup_claude_agents_md
      install_policy_file
    fi
    skills_install
    status
    ;;
  uninstall)
    doctor
    prepare_sources
    uninstall_agents
    backup_policy_md
    if [[ "${POLICY_MODE}" == "managed_block" ]]; then
      remove_managed_block
    else
      backup_claude_agents_md
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
  *)
    err "unknown action: ${ACTION}"
    usage
    exit 1
    ;;
esac
