#!/usr/bin/env bash
set -euo pipefail

ACTION="install"
TARGET=""
SEEN_TARGET_COUNT=0
CLAUDE_MD=""
PROJECT_SCOPE=1
SEEN_PROJECT=0
SEEN_GLOBAL=0
SKIP_SKILLS=0
SKIP_AGENTS_MD=0
SKILLS_CLI="skills@^1.5.21"  # pinned npx CLI package spec
SOURCE_MODE="auto"  # auto|local|web
BRANCH="main"  # default branch
RAW_BASE="https://raw.githubusercontent.com/sprngr/rubber-duck/main"
SKILLS_SOURCE=""  # derived from --source after choose_source
DRY_RUN=0
EXTRAS=0

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
POLICY_MODE="managed_block"  # managed_block|file
CANONICAL_VERSION="unknown"

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

AGENT_FILES=(
  "rubber-duck.md"
  "duckling.md"
)

# Default skills: the set declared in .claude-plugin/plugin.json.
DEFAULT_SKILLS=(
  "duck-debt"
  "duck-debug"
  "duck-design"
  "duck-patch"
  "duck-refactor"
  "duck-review"
  "duck-risk"
  "duck-simplify"
  "duck-teach"
  "duck-triage"
  "quack"
)

# Optional extras: installed only with --extras.
EXTRAS_SKILLS=(
  "duck-adapt"
  "duck-grill"
  "duck-tape"
)

usage() {
  cat <<'EOF'
Usage:
  scripts/rubber-duck.sh [install|uninstall|status|doctor] [options]

Options:
  --opencode                        Use opencode paths (required: pick exactly one target)
  --copilot                         Use Copilot paths (required: pick exactly one target)
  --claude                          Use Claude paths (required: pick exactly one target)
  --global                          Apply global scope to selected target (and skills, unless --skip-skills)
  --project                         Apply project scope to selected target (and skills, unless --skip-skills)
  --claude-md <path>                Claude target memory file path override
  --branch <name>                   Branch to install from (default: main, auto-detects from URL)
  --skip-skills                     Skip npx skills add/remove/list
  --skip-agents-md                  Skip AGENTS.md policy block install/remove
  --source <auto|local|web>         Artifact + skills source (default: auto)
  --raw-base <url>                  Raw GitHub base for web source
  --dry-run                         Print planned actions only
  --extras                          Also install extras skills (duck-adapt, duck-grill, duck-tape)
  -h, --help                        Show help

Examples:
  scripts/rubber-duck.sh install --opencode
  scripts/rubber-duck.sh install --opencode --extras
  scripts/rubber-duck.sh install --opencode --project
  scripts/rubber-duck.sh install --copilot --global
  scripts/rubber-duck.sh install --claude --skip-skills
  scripts/rubber-duck.sh install --opencode --source local
  curl -fsSL https://raw.githubusercontent.com/sprngr/rubber-duck/main/scripts/rubber-duck.sh | bash -s -- install --opencode
  curl -fsSL https://raw.githubusercontent.com/sprngr/rubber-duck/v2-quackening/scripts/rubber-duck.sh | bash -s -- install --opencode --branch v2-quackening
EOF
}

log() { printf '%s\n' "$*"; }
warn() { printf 'WARN: %s\n' "$*"; }
err() { printf 'ERROR: %s\n' "$*" >&2; }
timestamp() { date +%Y%m%d-%H%M%S; }

extract_version_from_file() {
  local source_file="$1"
  [[ -f "${source_file}" ]] || return 1
  awk 'match($0, /RUBBER_DUCK_VERSION:[[:space:]]*(v[0-9]+\.[0-9]+\.[0-9]+)/, m) { print m[1]; exit 0 }' "${source_file}"
}

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
      SEEN_TARGET_COUNT=$((SEEN_TARGET_COUNT + 1))
      shift
      ;;
    --copilot)
      TARGET="copilot"
      SEEN_TARGET_COUNT=$((SEEN_TARGET_COUNT + 1))
      shift
      ;;
    --claude)
      TARGET="claude"
      SEEN_TARGET_COUNT=$((SEEN_TARGET_COUNT + 1))
      shift
      ;;
    --project)
      PROJECT_SCOPE=1
      SEEN_PROJECT=1
      shift
      ;;
    --global)
      PROJECT_SCOPE=0
      SEEN_GLOBAL=1
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
    --skip-agents-md)
      SKIP_AGENTS_MD=1
      shift
      ;;
    --source)
      SOURCE_MODE="${2:-}"
      shift 2
      ;;
    --branch)
      BRANCH="${2:-}"
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
    --extras)
      EXTRAS=1
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

if (( SEEN_TARGET_COUNT == 0 )); then
  err "must specify exactly one target: --opencode, --copilot, or --claude"
  usage
  exit 1
fi

if (( SEEN_TARGET_COUNT > 1 )); then
  err "cannot combine multiple targets; choose exactly one: --opencode, --copilot, or --claude"
  exit 1
fi

if (( SEEN_PROJECT == 1 && SEEN_GLOBAL == 1 )); then
  err "cannot combine --project and --global"
  exit 1
fi

# Auto-detect branch from piped URL if not explicitly set
if [[ "${BRANCH}" == "main" ]]; then
  # Try to detect from common environment variables or process cmdline
  if [[ -n "${BASH_SOURCE_URL:-}" ]] && [[ "${BASH_SOURCE_URL}" =~ githubusercontent\.com/[^/]+/[^/]+/([^/]+)/ ]]; then
    DETECTED_BRANCH="${BASH_REMATCH[1]}"
    if [[ "${DETECTED_BRANCH}" != "main" ]]; then
      BRANCH="${DETECTED_BRANCH}"
      log "Auto-detected branch: ${BRANCH}"
    fi
  fi
fi

# Update RAW_BASE based on branch
RAW_BASE="https://raw.githubusercontent.com/sprngr/rubber-duck/${BRANCH}"
if [[ "${BRANCH}" != "main" ]]; then
  log "Using branch: ${BRANCH}"
fi

if [[ -n "${CLAUDE_MD}" && "${TARGET}" != "claude" ]]; then
  err "--claude-md requires --claude"
  exit 1
fi

resolve_target() {
  case "${TARGET}" in
    opencode)
      if (( PROJECT_SCOPE == 1 )); then
        DEST_AGENTS_DIR="${OPENCODE_PROJECT_AGENTS_DIR}"
        DEST_POLICY_MD="${OPENCODE_PROJECT_AGENTS_MD}"
      else
        DEST_AGENTS_DIR="${OPENCODE_AGENTS_DIR}"
        DEST_POLICY_MD="${OPENCODE_AGENTS_MD}"
      fi
      POLICY_MODE="managed_block"
      LOCAL_POLICY_FILE="${REPO_ROOT}/dist/AGENTS.md"
      if [[ -d "${REPO_ROOT}/dist/opencode/agents" ]]; then
        LOCAL_AGENTS_DIR="${REPO_ROOT}/dist/opencode/agents"
      else
        LOCAL_AGENTS_DIR="${REPO_ROOT}/agents"
      fi
      REMOTE_POLICY_PATH="dist/AGENTS.md"
      REMOTE_AGENTS_PATH="dist/opencode/agents"
      ;;
    copilot)
      if (( PROJECT_SCOPE == 1 )); then
        DEST_AGENTS_DIR="${COPILOT_PROJECT_AGENTS_DIR}"
        DEST_POLICY_MD="${COPILOT_PROJECT_AGENTS_MD}"
      else
        DEST_AGENTS_DIR="${COPILOT_AGENTS_DIR}"
        DEST_POLICY_MD="${COPILOT_AGENTS_MD}"
      fi
      POLICY_MODE="managed_block"
      LOCAL_POLICY_FILE="${REPO_ROOT}/dist/AGENTS.md"
      if [[ -d "${REPO_ROOT}/dist/copilot/agents" ]]; then
        LOCAL_AGENTS_DIR="${REPO_ROOT}/dist/copilot/agents"
      else
        LOCAL_AGENTS_DIR="${REPO_ROOT}/agents"
      fi
      REMOTE_POLICY_PATH="dist/AGENTS.md"
      REMOTE_AGENTS_PATH="dist/copilot/agents"
      ;;
    claude)
      if (( PROJECT_SCOPE == 1 )); then
        DEST_AGENTS_DIR="${CLAUDE_PROJECT_AGENTS_DIR}"
        DEST_POLICY_MD="${CLAUDE_MD:-${CLAUDE_PROJECT_POLICY_MD}}"
      else
        DEST_AGENTS_DIR="${CLAUDE_AGENTS_DIR}"
        DEST_POLICY_MD="${CLAUDE_MD:-${CLAUDE_POLICY_MD}}"
      fi
      DEST_CLAUDE_AGENTS_MD="$(dirname -- "${DEST_POLICY_MD}")/AGENTS.md"
      POLICY_MODE="file"
      LOCAL_POLICY_FILE="${REPO_ROOT}/dist/claude/CLAUDE.md"
      LOCAL_POLICY_AGENTS_FILE="${REPO_ROOT}/dist/AGENTS.md"
      LOCAL_AGENTS_DIR="${REPO_ROOT}/dist/claude/agents"
      REMOTE_POLICY_PATH="dist/claude/CLAUDE.md"
      REMOTE_POLICY_AGENTS_PATH="dist/AGENTS.md"
      REMOTE_AGENTS_PATH="dist/claude/agents"
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
    if v="$(extract_version_from_file "${TMP_DIR}/AGENTS.md" 2>/dev/null)"; then
      CANONICAL_VERSION="${v}"
    fi
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
  if v="$(extract_version_from_file "${TMP_DIR}/AGENTS.md" 2>/dev/null)"; then
    CANONICAL_VERSION="${v}"
  fi
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

trim_trailing_blank_lines() {
  local target="$1"
  local tmp
  tmp="$(mktemp)"
  awk '
    { lines[NR] = $0 }
    $0 ~ /[^[:space:]]/ { last = NR }
    END {
      for (i = 1; i <= last; i++) print lines[i]
    }
  ' "${target}" > "${tmp}"
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
  (( SKIP_AGENTS_MD == 1 )) && return 0
  local target="${1:-${DEST_POLICY_MD}}"
  local content_file="${2:-${TMP_DIR}/AGENTS.md}"
  if (( DRY_RUN == 1 )); then
    log "[dry-run] upsert managed block in ${target}"
    return
  fi
  mkdir -p "$(dirname -- "${target}")"
  touch "${target}"
  strip_managed_block "${target}"
  trim_trailing_blank_lines "${target}"
  local tmp_out
  tmp_out="$(mktemp)"
  {
    if [[ -s "${target}" ]]; then
      cat "${target}"
    fi
    printf '%s\n' "${MANAGED_START}"
    cat "${content_file}"
    printf '%s\n' "${MANAGED_END}"
  } > "${tmp_out}"
  mv "${tmp_out}" "${target}"
}

remove_managed_block() {
  (( SKIP_AGENTS_MD == 1 )) && return 0
  local target="${1:-${DEST_POLICY_MD}}"
  if (( DRY_RUN == 1 )); then
    log "[dry-run] remove managed block from ${target}"
    return
  fi
  [[ -f "${target}" ]] || return 0
  strip_managed_block "${target}"
}

install_policy_file() {
  (( SKIP_AGENTS_MD == 1 )) && return 0
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
  (( SKIP_AGENTS_MD == 1 )) && return 0
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
  local -a install_list=("${DEFAULT_SKILLS[@]}")
  (( PROJECT_SCOPE == 0 )) && scope="-g"
  (( EXTRAS == 1 )) && install_list+=("${EXTRAS_SKILLS[@]}")
  if (( DRY_RUN == 1 )); then
    log "[dry-run] npx ${SKILLS_CLI} add ${SKILLS_SOURCE} --skill ${install_list[*]} ${scope} -y"
    return
  fi
  if ! command -v npx >/dev/null 2>&1; then
    warn "npx not found; skipping skills install"
    return
  fi
  npx "${SKILLS_CLI}" add "${SKILLS_SOURCE}" --skill ${install_list[*]} ${scope} -y
}

skills_uninstall() {
  (( SKIP_SKILLS == 1 )) && return 0
  local scope=""
  local -a all_skills=("${DEFAULT_SKILLS[@]}" "${EXTRAS_SKILLS[@]}")
  (( PROJECT_SCOPE == 0 )) && scope="-g"
  if (( DRY_RUN == 1 )); then
    log "[dry-run] npx ${SKILLS_CLI} remove ${SKILLS_SOURCE} --skill ${all_skills[*]} ${scope} -y"
    return
  fi
  if ! command -v npx >/dev/null 2>&1; then
    warn "npx not found; skipping skills uninstall"
    return
  fi
  if ! npx "${SKILLS_CLI}" remove "${SKILLS_SOURCE}" --skill ${all_skills[*]} ${scope} -y; then
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
  local skill missing=0
  local -a extras_present=()
  (( PROJECT_SCOPE == 0 )) && scope="-g"
  SKILLS_LIST_CMD=(npx --yes "${SKILLS_CLI}" list ${scope})

  if list="$(NO_COLOR=1 "${SKILLS_LIST_CMD[@]}" </dev/null 2>/dev/null)"; then
    for skill in "${DEFAULT_SKILLS[@]}"; do
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
    for skill in "${EXTRAS_SKILLS[@]}"; do
      if printf '%s' "${list}" | grep -Fq -- "${skill}"; then
        extras_present+=("${skill}")
      fi
    done
    log "skills extras (optional): ${#extras_present[@]}/${#EXTRAS_SKILLS[@]} present${extras_present[*]:+ ([${extras_present[*]}])}"
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
  (( SKIP_AGENTS_MD == 1 )) && { log "AGENTS policy block (${target##*/}): skipped (--skip-agents-md)"; return 0; }
  has_managed_block "${target}" && state="present"
  log "AGENTS policy block (${target##*/}): ${state}"
}

status() {
  if v="$(extract_version_from_file "${DEST_POLICY_MD}" 2>/dev/null)"; then
    CANONICAL_VERSION="${v}"
  fi
  log "target: ${TARGET}"
  log "agents_dir: ${DEST_AGENTS_DIR}"
  log "policy_md: ${DEST_POLICY_MD}"
  log "version: ${CANONICAL_VERSION}"
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

case "${EFFECTIVE_SOURCE}" in
  local)
    SKILLS_SOURCE="${REPO_ROOT}"
    ;;
  web|*)
    if [[ "${BRANCH}" == "main" ]]; then
      SKILLS_SOURCE="https://github.com/sprngr/rubber-duck"
    else
      SKILLS_SOURCE="https://github.com/sprngr/rubber-duck#${BRANCH}"
    fi
    ;;
esac
log "Skills source: ${SKILLS_SOURCE}"

case "${ACTION}" in
  install)
    doctor
    prepare_sources
    install_agents
    if (( SKIP_AGENTS_MD == 0 )); then
      backup_md "${DEST_POLICY_MD}"
      if [[ "${POLICY_MODE}" == "managed_block" ]]; then
        upsert_managed_block
      else
        backup_md "${DEST_CLAUDE_AGENTS_MD}"
        install_policy_file
      fi
    fi
    skills_install
    status
    ;;
  uninstall)
    doctor
    prepare_sources
    uninstall_agents
    if (( SKIP_AGENTS_MD == 0 )); then
      backup_md "${DEST_POLICY_MD}"
      if [[ "${POLICY_MODE}" == "managed_block" ]]; then
        remove_managed_block
      else
        backup_md "${DEST_CLAUDE_AGENTS_MD}"
        remove_policy_file
      fi
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
