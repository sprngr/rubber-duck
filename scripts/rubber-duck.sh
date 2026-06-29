#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

SOURCE_AGENTS_DIR="${REPO_ROOT}/agents"
SOURCE_POLICY_FILE="${REPO_ROOT}/AGENTS.md"

MANAGED_START="<!-- RUBBER_DUCK_MANAGED_BLOCK START -->"
MANAGED_END="<!-- RUBBER_DUCK_MANAGED_BLOCK END -->"

TARGET="generic"
AGENTS_DIR=""
AGENTS_MD=""
SKILLS_SOURCE="https://github.com/sprngr/rubber-duck"
SKIP_SKILLS=0
DRY_RUN=0

OPENCODE_AGENTS_DIR="${HOME}/.config/opencode/agents"
OPENCODE_AGENTS_MD="${HOME}/.config/opencode/AGENTS.md"

usage() {
  cat <<'EOF'
Usage:
  scripts/rubber-duck.sh <install|uninstall|status|doctor> [options]

Options:
  --target <generic|opencode>           Target harness (default: generic)
  --agents-dir <path>                   Required for generic target
  --agents-md <path>                    Required for generic target
  --opencode                            Shortcut for --target opencode
  --skills-source <url-or-path>         Skills package source (default repo URL)
  --skip-skills                         Skip npx skills add/remove checks
  --dry-run                             Print planned actions and diff preview only
  -h, --help                            Show help

Examples:
  scripts/rubber-duck.sh install \
    --agents-dir ~/.myharness/agents \
    --agents-md ~/.myharness/AGENTS.md
  scripts/rubber-duck.sh status
  scripts/rubber-duck.sh install --opencode
  scripts/rubber-duck.sh uninstall \
    --agents-dir ~/.myharness/agents \
    --agents-md ~/.myharness/AGENTS.md
EOF
}

log() { printf '%s\n' "$*"; }
warn() { printf 'WARN: %s\n' "$*"; }
err() { printf 'ERROR: %s\n' "$*" >&2; }

timestamp() { date +%Y%m%d-%H%M%S; }

require_file() {
  local file="$1"
  if [[ ! -f "${file}" ]]; then
    err "missing required file: ${file}"
    exit 1
  fi
}

resolve_target() {
  case "${TARGET}" in
    generic)
      if [[ -z "${AGENTS_DIR}" || -z "${AGENTS_MD}" ]]; then
        err "generic target requires --agents-dir and --agents-md"
        exit 1
      fi
      DEST_AGENTS_DIR="${AGENTS_DIR}"
      DEST_AGENTS_MD="${AGENTS_MD}"
      ;;
    opencode)
      DEST_AGENTS_DIR="${OPENCODE_AGENTS_DIR}"
      DEST_AGENTS_MD="${OPENCODE_AGENTS_MD}"
      ;;
    *)
      err "invalid --target: ${TARGET}"
      exit 1
      ;;
  esac
}

collect_source_agents() {
  mapfile -t SOURCE_AGENT_FILES < <(compgen -G "${SOURCE_AGENTS_DIR}/*.agent.md" || true)
  if [[ "${#SOURCE_AGENT_FILES[@]}" -eq 0 ]]; then
    err "no source agent files found in ${SOURCE_AGENTS_DIR}"
    exit 1
  fi
}

strip_managed_block() {
  local target_file="$1"
  [[ -f "${target_file}" ]] || return 0
  local tmp
  tmp="$(mktemp)"
  strip_managed_block_to_file "${target_file}" "${tmp}"
  mv "${tmp}" "${target_file}"
}

strip_managed_block_to_file() {
  local source_file="$1"
  local out_file="$2"
  if [[ ! -f "${source_file}" ]]; then
    : > "${out_file}"
    return 0
  fi
  awk -v start="${MANAGED_START}" -v end="${MANAGED_END}" '
    $0 == start {in_block=1; next}
    $0 == end {in_block=0; next}
    !in_block {print}
  ' "${source_file}" > "${out_file}"
}

render_with_managed_block() {
  local source_file="$1"
  local out_file="$2"
  local stripped
  stripped="$(mktemp)"
  strip_managed_block_to_file "${source_file}" "${stripped}"
  {
    cat "${stripped}"
    printf '\n%s\n' "${MANAGED_START}"
    cat "${SOURCE_POLICY_FILE}"
    printf '%s\n' "${MANAGED_END}"
  } > "${out_file}"
  rm -f "${stripped}"
}

render_without_managed_block() {
  local source_file="$1"
  local out_file="$2"
  strip_managed_block_to_file "${source_file}" "${out_file}"
}

show_agents_md_diff_preview() {
  local action="$1"
  local target_file="$2"
  local old_file new_file diff_out
  old_file="$(mktemp)"
  new_file="$(mktemp)"

  if [[ -f "${target_file}" ]]; then
    cp -f "${target_file}" "${old_file}"
  else
    : > "${old_file}"
  fi

  case "${action}" in
    install) render_with_managed_block "${target_file}" "${new_file}" ;;
    uninstall) render_without_managed_block "${target_file}" "${new_file}" ;;
    *)
      err "invalid diff preview action: ${action}"
      rm -f "${old_file}" "${new_file}"
      exit 1
      ;;
  esac

  log "[dry-run] AGENTS.md diff preview (${target_file}):"
  diff_out="$(diff -u "${old_file}" "${new_file}" || true)"
  if [[ -n "${diff_out}" ]]; then
    printf '%s\n' "${diff_out}"
  else
    log "(no AGENTS.md content changes)"
  fi

  rm -f "${old_file}" "${new_file}"
}

backup_agents_md_before_modify() {
  local target_file="$1"
  local backup_file
  backup_file="${target_file}.bak.$(timestamp)"

  if (( DRY_RUN == 1 )); then
    log "[dry-run] backup ${target_file} -> ${backup_file}"
    return 0
  fi

  mkdir -p "$(dirname -- "${target_file}")"
  if [[ -f "${target_file}" ]]; then
    cp -f "${target_file}" "${backup_file}"
  else
    : > "${backup_file}"
  fi
  log "Backup created: ${backup_file}"
}

upsert_managed_block() {
  local target_file="$1"
  if (( DRY_RUN == 1 )); then
    show_agents_md_diff_preview install "${target_file}"
    return 0
  fi
  mkdir -p "$(dirname -- "${target_file}")"
  touch "${target_file}"
  strip_managed_block "${target_file}"

  {
    printf '\n%s\n' "${MANAGED_START}"
    cat "${SOURCE_POLICY_FILE}"
    printf '%s\n' "${MANAGED_END}"
  } >> "${target_file}"
}

remove_managed_block_only() {
  local target_file="$1"
  if (( DRY_RUN == 1 )); then
    show_agents_md_diff_preview uninstall "${target_file}"
    return 0
  fi
  if [[ ! -f "${target_file}" ]]; then
    return 0
  fi
  strip_managed_block "${target_file}"
}

install_agents() {
  if (( DRY_RUN == 1 )); then
    log "[dry-run] ensure dir ${DEST_AGENTS_DIR}"
    for src in "${SOURCE_AGENT_FILES[@]}"; do
      log "[dry-run] cp ${src} -> ${DEST_AGENTS_DIR}/$(basename -- "${src}")"
    done
    log "[dry-run] install ${#SOURCE_AGENT_FILES[@]} agents -> ${DEST_AGENTS_DIR}"
    return 0
  fi

  mkdir -p "${DEST_AGENTS_DIR}"
  for src in "${SOURCE_AGENT_FILES[@]}"; do
    cp -f "${src}" "${DEST_AGENTS_DIR}/$(basename -- "${src}")"
  done
  log "Installed ${#SOURCE_AGENT_FILES[@]} agents -> ${DEST_AGENTS_DIR}"
}

uninstall_agents() {
  if (( DRY_RUN == 1 )); then
    for src in "${SOURCE_AGENT_FILES[@]}"; do
      log "[dry-run] rm ${DEST_AGENTS_DIR}/$(basename -- "${src}")"
    done
    log "[dry-run] uninstall agents from ${DEST_AGENTS_DIR}"
    return 0
  fi

  local removed=0
  for src in "${SOURCE_AGENT_FILES[@]}"; do
    local dest
    dest="${DEST_AGENTS_DIR}/$(basename -- "${src}")"
    if [[ -f "${dest}" ]]; then
      rm -f "${dest}"
      removed=$((removed + 1))
    fi
  done
  log "Removed ${removed} agents from ${DEST_AGENTS_DIR}"
}

skills_install() {
  (( SKIP_SKILLS == 1 )) && return 0
  if (( DRY_RUN == 1 )); then
    log "[dry-run] npx skills add ${SKILLS_SOURCE}"
    return 0
  fi
  if ! command -v npx >/dev/null 2>&1; then
    warn "npx not found; skipping skills install"
    return 0
  fi
  npx skills add "${SKILLS_SOURCE}"
}

skills_uninstall() {
  (( SKIP_SKILLS == 1 )) && return 0
  if (( DRY_RUN == 1 )); then
    log "[dry-run] npx skills remove ${SKILLS_SOURCE}"
    return 0
  fi
  if ! command -v npx >/dev/null 2>&1; then
    warn "npx not found; skipping skills uninstall"
    return 0
  fi
  if ! npx skills remove "${SKILLS_SOURCE}"; then
    warn "skills remove command failed. If unsupported, remove package manually from skills manager."
  fi
}

skills_status() {
  if (( SKIP_SKILLS == 1 )); then
    log "skills: skipped (--skip-skills)"
    return 0
  fi
  if ! command -v npx >/dev/null 2>&1; then
    log "skills: npx missing"
    return 0
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
  local target_file="$1"
  [[ -f "${target_file}" ]] || return 1
  grep -Fq "${MANAGED_START}" "${target_file}" && grep -Fq "${MANAGED_END}" "${target_file}"
}

status() {
  local predicted_action="${1:-}"
  log "target: ${TARGET}"
  log "agents_dir: ${DEST_AGENTS_DIR}"
  log "agents_md: ${DEST_AGENTS_MD}"

  if (( DRY_RUN == 1 )) && [[ -n "${predicted_action}" ]]; then
    case "${predicted_action}" in
      install)
        log "agents (predicted): ${#SOURCE_AGENT_FILES[@]}/${#SOURCE_AGENT_FILES[@]} present"
        log "AGENTS policy block (predicted): present"
        if (( SKIP_SKILLS == 1 )); then
          log "skills (predicted): skipped (--skip-skills)"
        else
          log "skills (predicted): would run npx skills add ${SKILLS_SOURCE}"
        fi
        return 0
        ;;
      uninstall)
        log "agents (predicted): 0/${#SOURCE_AGENT_FILES[@]} present"
        log "AGENTS policy block (predicted): missing"
        if (( SKIP_SKILLS == 1 )); then
          log "skills (predicted): skipped (--skip-skills)"
        else
          log "skills (predicted): would run npx skills remove ${SKILLS_SOURCE}"
        fi
        return 0
        ;;
    esac
  fi

  local installed=0
  for src in "${SOURCE_AGENT_FILES[@]}"; do
    local dest
    dest="${DEST_AGENTS_DIR}/$(basename -- "${src}")"
    [[ -f "${dest}" ]] && installed=$((installed + 1))
  done
  log "agents: ${installed}/${#SOURCE_AGENT_FILES[@]} present"

  if has_managed_block "${DEST_AGENTS_MD}"; then
    log "AGENTS policy block: present"
  else
    log "AGENTS policy block: missing"
  fi

  skills_status
}

doctor() {
  local fail=0

  require_file "${SOURCE_POLICY_FILE}"
  if [[ ! -d "${SOURCE_AGENTS_DIR}" ]]; then
    err "source agents dir missing: ${SOURCE_AGENTS_DIR}"
    fail=1
  fi

  if ! command -v cp >/dev/null 2>&1; then
    err "cp command missing"
    fail=1
  fi

  if ! command -v awk >/dev/null 2>&1; then
    err "awk command missing"
    fail=1
  fi

  if (( DRY_RUN == 1 )); then
    if [[ ! -d "${DEST_AGENTS_DIR}" ]]; then
      warn "doctor: agents dir missing, would create: ${DEST_AGENTS_DIR}"
    fi
    if [[ ! -d "$(dirname -- "${DEST_AGENTS_MD}")" ]]; then
      warn "doctor: AGENTS.md parent missing, would create: $(dirname -- "${DEST_AGENTS_MD}")"
    fi
  else
    mkdir -p "${DEST_AGENTS_DIR}" || { err "cannot create/write agents dir: ${DEST_AGENTS_DIR}"; fail=1; }
    mkdir -p "$(dirname -- "${DEST_AGENTS_MD}")" || { err "cannot create/write AGENTS.md parent dir"; fail=1; }
  fi

  if (( SKIP_SKILLS == 0 )) && ! command -v npx >/dev/null 2>&1; then
    warn "npx missing; skills install/remove unavailable"
  fi

  if (( fail == 0 )); then
    log "doctor: ok"
  else
    err "doctor: failed"
    exit 1
  fi
}

COMMAND="${1:-}"
if [[ -z "${COMMAND}" ]]; then
  usage
  exit 1
fi
shift || true

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)
      TARGET="${2:-}"
      shift 2
      ;;
    --agents-dir)
      AGENTS_DIR="${2:-}"
      shift 2
      ;;
    --agents-md)
      AGENTS_MD="${2:-}"
      shift 2
      ;;
    --opencode)
      TARGET="opencode"
      shift
      ;;
    --skills-source)
      SKILLS_SOURCE="${2:-}"
      shift 2
      ;;
    --skip-skills)
      SKIP_SKILLS=1
      shift
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

resolve_target
collect_source_agents

case "${COMMAND}" in
  install)
    doctor
    install_agents
    backup_agents_md_before_modify "${DEST_AGENTS_MD}"
    upsert_managed_block "${DEST_AGENTS_MD}"
    skills_install
    status install
    ;;
  uninstall)
    uninstall_agents
    backup_agents_md_before_modify "${DEST_AGENTS_MD}"
    remove_managed_block_only "${DEST_AGENTS_MD}"
    skills_uninstall
    status uninstall
    ;;
  status)
    status
    ;;
  doctor)
    doctor
    ;;
  *)
    err "unknown command: ${COMMAND}"
    usage
    exit 1
    ;;
esac
