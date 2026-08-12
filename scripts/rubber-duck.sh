#!/usr/bin/env bash
set -euo pipefail

ACTION="install"
TARGET=""
SEEN_TARGET_COUNT=0
HARNESS_CSV=""
PRUNE=0
TARGETS=()
CLAUDE_MD=""
PROJECT_SCOPE=1
SEEN_PROJECT=0
SEEN_GLOBAL=0
SKIP_SKILLS=0
SKIP_AGENTS_MD=0
SKILLS_CLI="skills@^1.5.21"  # pinned npx CLI package spec
SOURCE_MODE="auto"  # auto|local|web
BRANCH="main"  # default branch
RAW_BASE=""  # default computed after branch resolution unless set via --raw-base
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
  scripts/rubber-duck.sh [install|uninstall|status|doctor|sync] [options]

Options:
  --opencode                        Use opencode paths (required: pick exactly one target)
  --copilot                         Use Copilot paths (required: pick exactly one target)
  --claude                          Use Claude paths (required: pick exactly one target)
  --harness <list>                  Comma-separated harness list (opencode,copilot,claude)
  --global                          Apply global scope to selected target (and skills, unless --skip-skills)
  --project                         Apply project scope to selected target (and skills, unless --skip-skills)
  --claude-md <path>                Claude target memory file path override
  --branch <name>                   Branch to install from (default: main, auto-detects from URL)
  --skip-skills                     Skip npx skills add/remove/list
  --skip-agents-md                  Skip AGENTS.md policy block install/remove
  --source <auto|local|web>         Artifact + skills source (default: auto)
  --raw-base <url>                  Raw GitHub base for web source
  --prune                           With sync: remove managed targets not in manifest
  --dry-run                         Print planned actions only
  --extras                          Also install extras skills (duck-adapt, duck-grill, duck-tape)
  --allow-untrusted-source          Skip rawBase allowlist check (dangerous; forks/custom mirrors)
  -h, --help                        Show help

Examples:
  scripts/rubber-duck.sh install --opencode
  scripts/rubber-duck.sh install --harness "opencode"
  scripts/rubber-duck.sh install --harness "opencode,copilot"
  scripts/rubber-duck.sh install --opencode --extras
  scripts/rubber-duck.sh install --opencode --project
  scripts/rubber-duck.sh install --copilot --global
  scripts/rubber-duck.sh install --claude --skip-skills
  scripts/rubber-duck.sh sync --project
  scripts/rubber-duck.sh sync --project --prune --skip-skills --skip-agents-md
  scripts/rubber-duck.sh install --opencode --source local
  curl -fsSL https://raw.githubusercontent.com/sprngr/rubber-duck/main/scripts/rubber-duck.sh | bash -s -- install --opencode
  curl -fsSL https://raw.githubusercontent.com/sprngr/rubber-duck/v2-quackening/scripts/rubber-duck.sh | bash -s -- install --opencode --branch v2-quackening
EOF
}

log() { printf '%s\n' "$*"; }
warn() { printf 'WARN: %s\n' "$*"; }
err() { printf 'ERROR: %s\n' "$*" >&2; }
timestamp() { date +%Y%m%d-%H%M%S; }

# Exact rawBase prefix required unless --allow-untrusted-source is set.
ALLOWED_RAW_BASE_PREFIX="https://raw.githubusercontent.com/sprngr/rubber-duck"
ALLOW_UNTRUSTED_SOURCE=0

# Compute SHA-256 of a file, print "sha256:<hex>". Returns 1 on error.
compute_sha256() {
  local file="$1" hash=""
  [[ -f "${file}" ]] || return 1
  if command -v sha256sum >/dev/null 2>&1; then
    hash=$(sha256sum "${file}" | awk '{print $1}')
  elif command -v shasum >/dev/null 2>&1; then
    hash=$(shasum -a 256 "${file}" | awk '{print $1}')
  else
    return 1
  fi
  [[ -n "${hash}" ]] && printf 'sha256:%s\n' "${hash}"
}

# Validate rawBase against ALLOWED_RAW_BASE_PREFIX. Skip check for local mode.
# Honor ALLOW_UNTRUSTED_SOURCE override. Returns 0 if allowed, 1 otherwise.
check_rawbase_allowed() {
  local raw_base="$1" mode="$2"
  [[ "${mode}" == "local" ]] && return 0
  (( ALLOW_UNTRUSTED_SOURCE == 1 )) && { warn "rawBase allowlist bypassed: ${raw_base}"; return 0; }
  [[ "${raw_base}" == "${ALLOWED_RAW_BASE_PREFIX}"* ]] && return 0
  return 1
}

# Verify artifact file matches manifest pin.
# Returns 0 on match, 1 on mismatch (with err message), 2 if pin missing.
verify_pin() {
  local artifact_path="$1" local_file="$2"
  [[ -z "${artifact_path}" || -z "${local_file}" ]] && return 2
  [[ -f "${MANIFEST_PATH:-}" ]] || return 2
  local expected
  expected=$(python3 -c "import json,sys; d=json.load(open(sys.argv[1])); print(d.get('pins',{}).get(sys.argv[2],''))" "${MANIFEST_PATH}" "${artifact_path}" 2>/dev/null || printf '')
  [[ -z "${expected}" ]] && return 2
  [[ -f "${local_file}" ]] || return 1
  local actual
  actual=$(compute_sha256 "${local_file}") || return 1
  if [[ "${actual}" != "${expected}" ]]; then
    err "pin mismatch for ${artifact_path}: expected ${expected}, got ${actual}"
    return 1
  fi
  return 0
}

# Write pins block into manifest. Remaining args: artifact_path=sha256_hash pairs.
write_pins() {
  local manifest_path="$1"
  shift
  (( $# == 0 )) && return 0
  require_cmd python3
  python3 - "${manifest_path}" "$@" <<'PY'
import json, sys, pathlib
path = sys.argv[1]
p = pathlib.Path(path)
data = {}
if p.exists():
    try: data = json.loads(p.read_text(encoding="utf-8") or "{}")
    except Exception: data = {}
pins = data.setdefault("pins", {})
for pair in sys.argv[2:]:
    if "=" in pair:
        k, v = pair.split("=", 1)
        pins[k] = v
p.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
}

# Warn when lastAppliedVersion is newer than sourceRef being installed.
warn_on_downgrade() {
  local last_applied="$1" incoming="$2"
  [[ -z "${last_applied}" || "${last_applied}" == "v0.0.0" || "${last_applied}" == "${incoming}" ]] && return 0
  local newer
  newer=$(printf '%s\n%s\n' "${last_applied}" "${incoming}" | sort -V | tail -1)
  [[ "${newer}" == "${last_applied}" ]] && warn "downgrade: manifest lastAppliedVersion ${last_applied} > incoming ${incoming}"
  return 0
}

extract_version_from_file() {
  local source_file="$1"
  [[ -f "${source_file}" ]] || return 1
  awk '
    match($0, /RUBBER_DUCK_VERSION:[[:space:]]*(v[0-9]+\.[0-9]+\.[0-9]+)/, m) { print m[1]; found=1; exit 0 }
    END { if (!found) exit 1 }
  ' "${source_file}"
}

if [[ $# -gt 0 ]]; then
  case "$1" in
    install|uninstall|status|doctor|sync)
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
    --harness)
      HARNESS_CSV="${2:-}"
      shift 2
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
    --prune)
      PRUNE=1
      shift
      ;;
    --allow-untrusted-source)
      ALLOW_UNTRUSTED_SOURCE=1
      shift
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

if (( SEEN_PROJECT == 1 && SEEN_GLOBAL == 1 )); then
  err "cannot combine --project and --global"
  exit 1
fi

if [[ -n "${HARNESS_CSV}" && ${SEEN_TARGET_COUNT} -gt 0 ]]; then
  err "cannot combine --harness with --opencode/--copilot/--claude"
  exit 1
fi

if [[ -n "${HARNESS_CSV}" ]]; then
  IFS=',' read -r -a HARNESS_ITEMS <<< "${HARNESS_CSV}"
  for RAW in "${HARNESS_ITEMS[@]}"; do
    T="${RAW//[[:space:]]/}"
    case "${T}" in
      opencode|copilot|claude) TARGETS+=("${T}") ;;
      "") ;;
      *) err "invalid harness in --harness: ${T}"; exit 1 ;;
    esac
  done
else
  if [[ "${ACTION}" == "sync" ]]; then
    TARGETS=()
  else
    if (( SEEN_TARGET_COUNT == 0 )); then
      err "must specify target via --harness or one legacy target flag"
      usage
      exit 1
    fi
    if (( SEEN_TARGET_COUNT > 1 )); then
      err "cannot combine multiple legacy targets; use --harness for multi-target"
      exit 1
    fi
    TARGETS+=("${TARGET}")
  fi
fi

if (( PRUNE == 1 )) && [[ "${ACTION}" != "sync" ]]; then
  err "--prune is only valid with sync"
  exit 1
fi

HAS_CLAUDE=0
for T in "${TARGETS[@]}"; do
  [[ "${T}" == "claude" ]] && HAS_CLAUDE=1
done
if [[ -n "${CLAUDE_MD}" && ${HAS_CLAUDE} -eq 0 ]]; then
  err "--claude-md applies only when claude target is selected"
  exit 1
fi

if (( PROJECT_SCOPE == 1 )); then
  MANIFEST_PATH=".rubber-duck/manifest.json"
else
  MANIFEST_PATH="${HOME}/.config/rubber-duck/manifest.json"
fi

if [[ "${ACTION}" == "sync" ]]; then
  if [[ ! -f "${MANIFEST_PATH}" ]]; then
    err "manifest missing: ${MANIFEST_PATH}. Run install first."
    exit 1
  fi
  if [[ "${0:-}" == "bash" || "${0:-}" == "sh" || "${0:-}" == "-" ]]; then
    err "sync requires file-backed execution (not piped)"
    exit 1
  fi
  check_rawbase_allowed "${RAW_BASE}" "${SOURCE_MODE}" || { err "rawBase not in allowlist: ${RAW_BASE}. Use --allow-untrusted-source to override."; exit 1; }
  command -v python3 >/dev/null 2>&1 || { err "required command missing: python3"; exit 1; }
  mapfile -t SYNC_TARGETS < <(
    python3 - "${MANIFEST_PATH}" <<'PY'
import json, sys
data = json.load(open(sys.argv[1], encoding="utf-8"))
targets = data.get("targets", {})
for name, cfg in targets.items():
    if cfg.get("enabled", True):
        print(name)
PY
  )
  declare -A SYNC_TARGET_SET=()
  for T in "${SYNC_TARGETS[@]}"; do
    SYNC_TARGET_SET["${T}"]=1
  done
  if (( ${#SYNC_TARGETS[@]} == 0 )); then
    log "sync: no enabled targets in manifest"
    if (( PRUNE == 0 )); then
      exit 0
    fi
  fi
  if (( ${#SYNC_TARGETS[@]} > 0 )); then
    for T in "${SYNC_TARGETS[@]}"; do
      CMD=(bash "${SCRIPT_PATH}" install --harness "${T}" --source "${SOURCE_MODE}" --branch "${BRANCH}" --raw-base "${RAW_BASE}")
      if (( PROJECT_SCOPE == 1 )); then CMD+=(--project); else CMD+=(--global); fi
      (( SKIP_SKILLS == 1 )) && CMD+=(--skip-skills)
      (( SKIP_AGENTS_MD == 1 )) && CMD+=(--skip-agents-md)
      (( EXTRAS == 1 )) && CMD+=(--extras)
      (( DRY_RUN == 1 )) && CMD+=(--dry-run)
      (( ALLOW_UNTRUSTED_SOURCE == 1 )) && CMD+=(--allow-untrusted-source)
      "${CMD[@]}"
    done
  fi
  if (( PRUNE == 1 )); then
    for T in opencode copilot claude; do
      if [[ -z "${SYNC_TARGET_SET[${T}]+x}" ]]; then
        CMD=(bash "${SCRIPT_PATH}" uninstall --harness "${T}" --source "${SOURCE_MODE}" --branch "${BRANCH}" --raw-base "${RAW_BASE}")
        if (( PROJECT_SCOPE == 1 )); then CMD+=(--project); else CMD+=(--global); fi
        CMD+=(--skip-skills)
        (( SKIP_AGENTS_MD == 1 )) && CMD+=(--skip-agents-md)
        (( DRY_RUN == 1 )) && CMD+=(--dry-run)
        (( ALLOW_UNTRUSTED_SOURCE == 1 )) && CMD+=(--allow-untrusted-source)
        "${CMD[@]}"
      fi
    done
  fi
  log "sync: complete"
  exit 0
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

# Default RAW_BASE from branch if not explicitly set via --raw-base
if [[ -z "${RAW_BASE}" ]]; then
  RAW_BASE="https://raw.githubusercontent.com/sprngr/rubber-duck/${BRANCH}"
fi
if [[ "${BRANCH}" != "main" ]]; then
  log "Using branch: ${BRANCH}"
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
  local backups=()
  local keep_index=0
  backups=( "${target}".bak.* )
  if [[ -e "${backups[0]:-}" ]]; then
    keep_index=$((${#backups[@]} - 1))
    for i in "${!backups[@]}"; do
      (( i == keep_index )) && continue
      rm -f "${backups[$i]}"
    done
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
      printf '\n'
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

manifest_update_target() {
  local op="$1" target_name="$2"
  (( DRY_RUN == 1 )) && { log "[dry-run] manifest ${op} ${target_name} -> ${MANIFEST_PATH}"; return 0; }
  local prior_version=""
  if [[ -f "${MANIFEST_PATH}" ]] && command -v python3 >/dev/null 2>&1; then
    prior_version=$(python3 -c "import json,sys; d=json.load(open(sys.argv[1])); print(d.get('source',{}).get('lastAppliedVersion',''))" "${MANIFEST_PATH}" 2>/dev/null || printf '')
  fi
  warn_on_downgrade "${prior_version}" "${CANONICAL_VERSION}"
  require_cmd python3
  mkdir -p "$(dirname -- "${MANIFEST_PATH}")"
  local template_path="${REPO_ROOT}/.rubber-duck/manifest.template.json"
  python3 - "${MANIFEST_PATH}" "${op}" "${target_name}" "${PROJECT_SCOPE}" "${SKIP_AGENTS_MD}" "${SKIP_SKILLS}" "${EXTRAS}" "${EFFECTIVE_SOURCE}" "${BRANCH}" "${RAW_BASE}" "${CANONICAL_VERSION}" "${template_path}" <<'PY'
import json, sys, pathlib
path, op, target = sys.argv[1], sys.argv[2], sys.argv[3]
project_scope = sys.argv[4] == "1"
skip_agents_md = sys.argv[5] == "1"
skip_skills = sys.argv[6] == "1"
extras = sys.argv[7] == "1"
effective_source, branch, raw_base, version = sys.argv[8], sys.argv[9], sys.argv[10], sys.argv[11]
template_path = sys.argv[12] if len(sys.argv) > 12 else ""
p = pathlib.Path(path)
data = {}
if p.exists():
    try: data = json.loads(p.read_text(encoding="utf-8") or "{}")
    except Exception: data = {}
elif template_path:
    tp = pathlib.Path(template_path)
    if tp.exists():
        try: data = json.loads(tp.read_text(encoding="utf-8"))
        except Exception: data = {}
data.setdefault("schemaVersion", 1)
data["source"] = {"mode": effective_source, "sourceRef": branch, "rawBase": raw_base, "lastAppliedVersion": version}
targets = data.setdefault("targets", {})
if op == "install":
    targets[target] = {"enabled": True, "scope": "project" if project_scope else "global", "installAgentsMd": not skip_agents_md, "installSkills": not skip_skills, "extras": extras}
elif op == "uninstall":
    targets.pop(target, None)
p.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
}

for TARGET in "${TARGETS[@]}"; do
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

  check_rawbase_allowed "${RAW_BASE}" "${EFFECTIVE_SOURCE}" || { err "rawBase not in allowlist: ${RAW_BASE}. Use --allow-untrusted-source to override."; exit 1; }

  case "${ACTION}" in
    install)
      doctor
      prepare_sources
      install_agents
      for pin_f in "${AGENT_FILES[@]}"; do
        pin_rc=0; verify_pin "${REMOTE_AGENTS_PATH}/${pin_f}" "${TMP_DIR}/${pin_f}" || pin_rc=$?
        (( pin_rc == 1 )) && exit 1
      done
      if (( SKIP_AGENTS_MD == 0 )); then
        pin_policy="${TMP_DIR}/AGENTS.md"
        [[ "${POLICY_MODE}" == "file" ]] && pin_policy="${TMP_DIR}/CLAUDE.md"
        pin_rc=0; verify_pin "${REMOTE_POLICY_PATH}" "${pin_policy}" || pin_rc=$?
        (( pin_rc == 1 )) && exit 1
      fi
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
      manifest_update_target "install" "${TARGET}"
      PIN_PAIRS=()
      for pin_f in "${AGENT_FILES[@]}"; do
        pin_h=$(compute_sha256 "${TMP_DIR}/${pin_f}") && PIN_PAIRS+=("${REMOTE_AGENTS_PATH}/${pin_f}=${pin_h}")
      done
      if (( SKIP_AGENTS_MD == 0 )); then
        pin_policy="${TMP_DIR}/AGENTS.md"
        [[ "${POLICY_MODE}" == "file" ]] && pin_policy="${TMP_DIR}/CLAUDE.md"
        pin_h=$(compute_sha256 "${pin_policy}") && PIN_PAIRS+=("${REMOTE_POLICY_PATH}=${pin_h}")
      fi
      write_pins "${MANIFEST_PATH}" "${PIN_PAIRS[@]}"
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
      manifest_update_target "uninstall" "${TARGET}"
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
done
