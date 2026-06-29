#!/usr/bin/env bash
set -euo pipefail

ACTION="install"
TARGET="generic"
AGENTS_DIR=""
AGENTS_MD=""
SKIP_SKILLS=0
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
LOCAL_AGENTS_DIR="${REPO_ROOT}/agents"
LOCAL_POLICY_FILE="${REPO_ROOT}/AGENTS.md"

MANAGED_START="<!-- RUBBER_DUCK_MANAGED_BLOCK START -->"
MANAGED_END="<!-- RUBBER_DUCK_MANAGED_BLOCK END -->"

OPENCODE_AGENTS_DIR="${HOME}/.config/opencode/agents"
OPENCODE_AGENTS_MD="${HOME}/.config/opencode/AGENTS.md"

AGENT_FILES=(
  "rubber-duck.agent.md"
  "duck-simple.agent.md"
  "duck-reviewer.agent.md"
  "duck-investigator.agent.md"
  "duck-dry.agent.md"
  "duck-builder.agent.md"
  "duck-adversary.agent.md"
)

usage() {
  cat <<'EOF'
Usage:
  scripts/rubber-duck.sh [install|uninstall|status|doctor] [options]

Options:
  --opencode                        Use preconfigured opencode paths
  --agents-dir <path>               Generic target agents dir
  --agents-md <path>                Generic target AGENTS.md path
  --skip-skills                     Skip npx skills add/remove/list
  --skills-source <url-or-path>     Skills package source
  --source <auto|local|web>         Artifact source (default: auto)
  --raw-base <url>                  Raw GitHub base for web source
  --dry-run                         Print planned actions only
  -h, --help                        Show help

Examples:
  scripts/rubber-duck.sh install --opencode
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
    --skip-skills)
      SKIP_SKILLS=1
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

resolve_target() {
  case "${TARGET}" in
    opencode)
      DEST_AGENTS_DIR="${OPENCODE_AGENTS_DIR}"
      DEST_AGENTS_MD="${OPENCODE_AGENTS_MD}"
      ;;
    generic)
      if [[ -z "${AGENTS_DIR}" || -z "${AGENTS_MD}" ]]; then
        err "generic target requires --agents-dir and --agents-md (or use --opencode)"
        exit 1
      fi
      DEST_AGENTS_DIR="${AGENTS_DIR}"
      DEST_AGENTS_MD="${AGENTS_MD}"
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
    cp -f "${LOCAL_POLICY_FILE}" "${TMP_DIR}/AGENTS.md"
    for f in "${AGENT_FILES[@]}"; do
      cp -f "${LOCAL_AGENTS_DIR}/${f}" "${TMP_DIR}/${f}"
    done
    log "source: local (${REPO_ROOT})"
    return
  fi

  require_cmd curl
  curl -fsSL "${RAW_BASE}/AGENTS.md" -o "${TMP_DIR}/AGENTS.md"
  for f in "${AGENT_FILES[@]}"; do
    curl -fsSL "${RAW_BASE}/agents/${f}" -o "${TMP_DIR}/${f}"
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

backup_agents_md() {
  local backup
  backup="${DEST_AGENTS_MD}.bak.$(timestamp)"
  if (( DRY_RUN == 1 )); then
    log "[dry-run] backup ${DEST_AGENTS_MD} -> ${backup}"
    return
  fi
  mkdir -p "$(dirname -- "${DEST_AGENTS_MD}")"
  if [[ -f "${DEST_AGENTS_MD}" ]]; then
    cp -f "${DEST_AGENTS_MD}" "${backup}"
  else
    : > "${backup}"
  fi
  log "Backup created: ${backup}"
}

upsert_managed_block() {
  if (( DRY_RUN == 1 )); then
    log "[dry-run] upsert managed block in ${DEST_AGENTS_MD}"
    return
  fi
  mkdir -p "$(dirname -- "${DEST_AGENTS_MD}")"
  touch "${DEST_AGENTS_MD}"
  strip_managed_block "${DEST_AGENTS_MD}"
  {
    printf '\n%s\n' "${MANAGED_START}"
    cat "${TMP_DIR}/AGENTS.md"
    printf '%s\n' "${MANAGED_END}"
  } >> "${DEST_AGENTS_MD}"
}

remove_managed_block() {
  if (( DRY_RUN == 1 )); then
    log "[dry-run] remove managed block from ${DEST_AGENTS_MD}"
    return
  fi
  [[ -f "${DEST_AGENTS_MD}" ]] || return 0
  strip_managed_block "${DEST_AGENTS_MD}"
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
    log "[dry-run] npx skills add ${SKILLS_SOURCE}"
    return
  fi
  if ! command -v npx >/dev/null 2>&1; then
    warn "npx not found; skipping skills install"
    return
  fi
  npx skills add "${SKILLS_SOURCE}"
}

skills_uninstall() {
  (( SKIP_SKILLS == 1 )) && return 0
  if (( DRY_RUN == 1 )); then
    log "[dry-run] npx skills remove ${SKILLS_SOURCE}"
    return
  fi
  if ! command -v npx >/dev/null 2>&1; then
    warn "npx not found; skipping skills uninstall"
    return
  fi
  if ! npx skills remove "${SKILLS_SOURCE}"; then
    warn "skills remove failed; remove package manually if needed"
  fi
}

skills_status() {
  (( SKIP_SKILLS == 1 )) && { log "skills: skipped (--skip-skills)"; return 0; }
  if ! command -v npx >/dev/null 2>&1; then
    log "skills: npx missing"
    return
  fi
  if npx skills list >/tmp/rubber-duck-skills-list.txt 2>/tmp/rubber-duck-skills-list.err; then
    if grep -Fq "${SKILLS_SOURCE}" /tmp/rubber-duck-skills-list.txt; then
      log "skills: installed (${SKILLS_SOURCE})"
    else
      log "skills: not detected (${SKILLS_SOURCE})"
    fi
  else
    log "skills: unable to query (npx skills list failed)"
  fi
}

has_managed_block() {
  [[ -f "${DEST_AGENTS_MD}" ]] || return 1
  grep -Fq "${MANAGED_START}" "${DEST_AGENTS_MD}" && grep -Fq "${MANAGED_END}" "${DEST_AGENTS_MD}"
}

status() {
  log "target: ${TARGET}"
  log "agents_dir: ${DEST_AGENTS_DIR}"
  log "agents_md: ${DEST_AGENTS_MD}"
  local installed=0
  for f in "${AGENT_FILES[@]}"; do
    [[ -f "${DEST_AGENTS_DIR}/${f}" ]] && installed=$((installed + 1))
  done
  log "agents: ${installed}/${#AGENT_FILES[@]} present"
  if has_managed_block; then
    log "AGENTS policy block: present"
  else
    log "AGENTS policy block: missing"
  fi
  skills_status
}

doctor() {
  resolve_target
  choose_source
  require_cmd awk
  require_cmd cp
  if [[ "${EFFECTIVE_SOURCE}" == "web" ]]; then require_cmd curl; fi
  if (( DRY_RUN == 1 )); then
    [[ -d "${DEST_AGENTS_DIR}" ]] || warn "doctor: agents dir missing, would create: ${DEST_AGENTS_DIR}"
    [[ -d "$(dirname -- "${DEST_AGENTS_MD}")" ]] || warn "doctor: AGENTS parent missing, would create: $(dirname -- "${DEST_AGENTS_MD}")"
  else
    mkdir -p "${DEST_AGENTS_DIR}"
    mkdir -p "$(dirname -- "${DEST_AGENTS_MD}")"
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
    backup_agents_md
    upsert_managed_block
    skills_install
    status
    ;;
  uninstall)
    doctor
    prepare_sources
    uninstall_agents
    backup_agents_md
    remove_managed_block
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
