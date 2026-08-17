#!/usr/bin/env bash
set -euo pipefail

ACTION="install"
TARGET=""
SEEN_TARGET_COUNT=0
HARNESS_CSV=""
PRUNE=0
TARGETS=()
PROJECT_SCOPE=1
SEEN_PROJECT=0
SEEN_GLOBAL=0
SKIP_SKILLS=0
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
REMOTE_AGENTS_PATH=""
REMOTE_POLICY_PATH=""
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
SYNC_WRAPPER_TEMPLATE_REMOTE="dist/scripts/sync-latest.sh"
SYNC_WRAPPER_WRITTEN=0
MANIFEST_TEMPLATE_PATH="dist/templates/manifest.template.json"

AGENT_FILES=(
  "rubber-duck.md"
  "duckling.md"
)

agent_remote_pin_key() {
  local dest_file="$1"
  printf '%s/%s' "${REMOTE_AGENTS_PATH}" "${dest_file}"
}

# Default skills: the set declared in .claude-plugin/plugin.json.
DEFAULT_SKILLS=(
  "duck-debt"
  "duck-debug"
  "duck-design"
  "duck-patch"
  "duck-policy"
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
  --branch <name>                   Branch to install from (default: main, auto-detects from URL)
  --skip-skills                     Skip npx skills add/remove/list
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
  scripts/rubber-duck.sh install --opencode --source local
  curl -fsSL https://raw.githubusercontent.com/sprngr/rubber-duck/main/scripts/rubber-duck.sh -o /tmp/rubber-duck.sh && bash -n /tmp/rubber-duck.sh && bash /tmp/rubber-duck.sh install --opencode
  curl -fsSL https://raw.githubusercontent.com/sprngr/rubber-duck/v2-quackening/scripts/rubber-duck.sh -o /tmp/rubber-duck.sh && bash -n /tmp/rubber-duck.sh && bash /tmp/rubber-duck.sh install --opencode --branch v2-quackening
EOF
}

log() { printf '%s\n' "$*"; }
warn() { printf 'WARN: %s\n' "$*"; }
err() { printf 'ERROR: %s\n' "$*" >&2; }
timestamp() { date +%Y%m%d-%H%M%S; }

print_banner() {
  cat <<'BANNER'
          _    _                    _         _
 _ _ _  _| |__| |__  ___ _ _ ___ __| |_  _ __| |__
| '_| || | '_ \ '_ \/ -_) '_|___/ _` | || / _| / /
|_|  \_,_|_.__/_.__/\___|_|     \__,_|\_,_\__|_\_\

BANNER
}

resolve_canonical_version() {
  local v=""
  if [[ "${EFFECTIVE_SOURCE}" == "local" ]]; then
    v="$(read_plain_version "${REPO_ROOT}/VERSION" 2>/dev/null)" || true
  else
    command -v curl >/dev/null 2>&1 || return 0
    local tmp
    tmp="$(mktemp)"
    if ! curl -fsSL "${RAW_BASE}/VERSION" -o "${tmp}" 2>/dev/null; then
      rm -f "${tmp}"
      return 0
    fi
    v="$(read_plain_version "${tmp}" 2>/dev/null)" || true
    rm -f "${tmp}"
  fi
  [[ -n "${v}" ]] && CANONICAL_VERSION="${v}"
}

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

manifest_path() {
  if (( PROJECT_SCOPE == 1 )); then
    printf '.rubber-duck/manifest.json'
  else
    printf '%s/.config/rubber-duck/manifest.json' "${HOME}"
  fi
}

sync_replay_cmd() {
  local action="$1" harness_csv="$2"
  CMD=(bash "${SCRIPT_PATH}" "${action}" --harness "${harness_csv}" --source "${SOURCE_MODE}" --branch "${BRANCH}" --raw-base "${RAW_BASE}")
  if (( PROJECT_SCOPE == 1 )); then CMD+=(--project); else CMD+=(--global); fi
  if [[ "${action}" == "install" ]]; then
    [[ "${3:-}" == "false" ]] && CMD+=(--skip-skills)
    [[ "${4:-}" == "true" ]] && CMD+=(--extras)
  else
    CMD+=(--skip-skills)
  fi
  (( DRY_RUN == 1 )) && CMD+=(--dry-run)
  (( ALLOW_UNTRUSTED_SOURCE == 1 )) && CMD+=(--allow-untrusted-source)
  return 0
}

rawbase_check_mode() {
  if [[ -n "${EFFECTIVE_SOURCE:-}" ]]; then
    printf '%s' "${EFFECTIVE_SOURCE}"
  else
    printf '%s' "${SOURCE_MODE}"
  fi
}

# --- Manifest handling (pure bash, no python3) ---
# Global state populated by manifest_load, consumed by manifest_save.
declare -A MF_TARGET_ENABLED=() MF_TARGET_SCOPE=() MF_TARGET_INSTALL_AGENTS_MD=() MF_TARGET_INSTALL_SKILLS=() MF_TARGET_EXTRAS=()
declare -a MF_TARGET_NAMES=()
declare -A MF_PINS=()
MF_SCHEMA_VERSION=1
MF_SOURCE_MODE=""
MF_SOURCE_REF=""
MF_SOURCE_RAW_BASE=""
MF_SOURCE_LAST_APPLIED_VERSION=""

manifest_reset() {
  MF_TARGET_ENABLED=(); MF_TARGET_SCOPE=(); MF_TARGET_INSTALL_AGENTS_MD=()
  MF_TARGET_INSTALL_SKILLS=(); MF_TARGET_EXTRAS=(); MF_TARGET_NAMES=(); MF_PINS=()
  MF_SCHEMA_VERSION=1
  MF_SOURCE_MODE=""; MF_SOURCE_REF=""; MF_SOURCE_RAW_BASE=""; MF_SOURCE_LAST_APPLIED_VERSION=""
}

# Load manifest into MF_* globals. Falls back to template if primary missing.
# Args: manifest_path [template_path]
manifest_load() {
  local mp="$1" tpl="${2:-}"
  manifest_reset
  local src=""
  [[ -f "${mp}" ]] && src="${mp}"
  [[ -z "${src}" && -n "${tpl}" && -f "${tpl}" ]] && src="${tpl}"
  [[ -z "${src}" ]] && return 0
  local block="" current="" line
  while IFS= read -r line || [[ -n "${line}" ]]; do
    if [[ "${line}" =~ ^\ \ \"source\":[[:space:]]*\{ ]]; then block="source"; continue; fi
    if [[ "${line}" =~ ^\ \ \"pins\":[[:space:]]*\{ ]]; then block="pins"; continue; fi
    if [[ "${line}" =~ ^\ \ \"targets\":[[:space:]]*\{ ]]; then block="targets"; continue; fi
    if [[ "${line}" =~ ^\ \ \} ]]; then block=""; current=""; continue; fi
    if [[ -z "${block}" && "${line}" =~ \"schemaVersion\":[[:space:]]*([0-9]+) ]]; then
      MF_SCHEMA_VERSION="${BASH_REMATCH[1]}"; continue
    fi
    if [[ "${block}" == "source" && "${line}" =~ \"([^\"]+)\":[[:space:]]*\"([^\"]*)\" ]]; then
      case "${BASH_REMATCH[1]}" in
        mode) MF_SOURCE_MODE="${BASH_REMATCH[2]}" ;;
        sourceRef) MF_SOURCE_REF="${BASH_REMATCH[2]}" ;;
        rawBase) MF_SOURCE_RAW_BASE="${BASH_REMATCH[2]}" ;;
        lastAppliedVersion) MF_SOURCE_LAST_APPLIED_VERSION="${BASH_REMATCH[2]}" ;;
      esac
      continue
    fi
    if [[ "${block}" == "pins" && "${line}" =~ \"([^\"]+)\":[[:space:]]*\"([^\"]*)\" ]]; then
      MF_PINS["${BASH_REMATCH[1]}"]="${BASH_REMATCH[2]}"; continue
    fi
    if [[ "${block}" == "targets" && "${line}" =~ ^\ \ \ \ \"([^\"]+)\":[[:space:]]*\{ ]]; then
      current="${BASH_REMATCH[1]}"; MF_TARGET_NAMES+=("${current}"); continue
    fi
    if [[ "${block}" == "targets" && -n "${current}" && "${line}" =~ \"([^\"]+)\":[[:space:]]*(true|false) ]]; then
      case "${BASH_REMATCH[1]}" in
        enabled) MF_TARGET_ENABLED["${current}"]="${BASH_REMATCH[2]}" ;;
        extras) MF_TARGET_EXTRAS["${current}"]="${BASH_REMATCH[2]}" ;;
        installAgentsMd) MF_TARGET_INSTALL_AGENTS_MD["${current}"]="${BASH_REMATCH[2]}" ;;
        installSkills) MF_TARGET_INSTALL_SKILLS["${current}"]="${BASH_REMATCH[2]}" ;;
      esac
      continue
    fi
    if [[ "${block}" == "targets" && -n "${current}" && "${line}" =~ \"scope\":[[:space:]]*\"([^\"]*)\" ]]; then
      MF_TARGET_SCOPE["${current}"]="${BASH_REMATCH[1]}"; continue
    fi
    if [[ "${block}" == "targets" && -n "${current}" && "${line}" =~ ^\ \ \ \ \} ]]; then
      current=""; continue
    fi
  done < "${src}"
}

# Save MF_* globals as sorted JSON. Matches python json.dumps(indent=2, sort_keys=True).
manifest_save() {
  local mp="$1"
  mkdir -p "$(dirname -- "${mp}")"
  local tmp="${mp}.tmp.$$"
  local -a sorted_pins=() sorted_targets=()
  (( ${#MF_PINS[@]} > 0 )) && mapfile -t sorted_pins < <(printf '%s\n' "${!MF_PINS[@]}" | sort)
  (( ${#MF_TARGET_NAMES[@]} > 0 )) && mapfile -t sorted_targets < <(printf '%s\n' "${MF_TARGET_NAMES[@]}" | sort -u)
  {
    printf '{\n'
    if (( ${#sorted_pins[@]} == 0 )); then
      printf '  "pins": {},\n'
    else
      printf '  "pins": {\n'
      local i=0 last=$((${#sorted_pins[@]} - 1)) k
      for k in "${sorted_pins[@]}"; do
        printf '    "%s": "%s"' "${k}" "${MF_PINS[$k]}"
        (( i < last )) && printf ','
        printf '\n'; i=$((i + 1))
      done
      printf '  },\n'
    fi
    printf '  "schemaVersion": %s,\n' "${MF_SCHEMA_VERSION}"
    printf '  "source": {\n'
    printf '    "lastAppliedVersion": "%s",\n' "${MF_SOURCE_LAST_APPLIED_VERSION}"
    printf '    "mode": "%s",\n' "${MF_SOURCE_MODE}"
    printf '    "rawBase": "%s",\n' "${MF_SOURCE_RAW_BASE}"
    printf '    "sourceRef": "%s"\n' "${MF_SOURCE_REF}"
    printf '  },\n'
    if (( ${#sorted_targets[@]} == 0 )); then
      printf '  "targets": {}\n'
    else
      printf '  "targets": {\n'
      local i=0 last=$((${#sorted_targets[@]} - 1)) t
      for t in "${sorted_targets[@]}"; do
        printf '    "%s": {\n' "${t}"
        printf '      "enabled": %s,\n' "${MF_TARGET_ENABLED[$t]:-true}"
        printf '      "extras": %s,\n' "${MF_TARGET_EXTRAS[$t]:-false}"
        printf '      "installAgentsMd": %s,\n' "${MF_TARGET_INSTALL_AGENTS_MD[$t]:-true}"
        printf '      "installSkills": %s,\n' "${MF_TARGET_INSTALL_SKILLS[$t]:-true}"
        printf '      "scope": "%s"\n' "${MF_TARGET_SCOPE[$t]:-project}"
        printf '    }'
        (( i < last )) && printf ','
        printf '\n'; i=$((i + 1))
      done
      printf '  }\n'
    fi
    printf '}\n'
  } > "${tmp}"
  mv "${tmp}" "${mp}"
}

# Write pins block into manifest. Remaining args: artifact_path=sha256_hash pairs.
write_pins() {
  local manifest_path="$1"
  shift
  (( $# == 0 )) && return 0
  (( DRY_RUN == 1 )) && { log "[dry-run] pins update -> ${manifest_path}"; return 0; }
  local template_path="${REPO_ROOT}/${MANIFEST_TEMPLATE_PATH}"
  manifest_load "${manifest_path}" "${template_path}"
  local pair k v
  for pair in "$@"; do
    IFS='=' read -r k v <<<"${pair}"
    MF_PINS["${k}"]="${v}"
  done
  manifest_save "${manifest_path}"
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

# Read prior lastAppliedVersion from manifest. Prints empty string when missing.
read_prior_version() {
  local mp="$1"
  [[ -f "${mp}" ]] || { printf ''; return; }
  manifest_load "${mp}"
  printf '%s' "${MF_SOURCE_LAST_APPLIED_VERSION}"
}

extract_version_from_file() {
  local source_file="$1"
  [[ -f "${source_file}" ]] || return 1
  awk '
    match($0, /RUBBER_DUCK_VERSION:[[:space:]]*(v[0-9]+\.[0-9]+\.[0-9]+)/, m) { print m[1]; found=1; exit 0 }
    END { if (!found) exit 1 }
  ' "${source_file}"
}

# Read a plain VERSION file (content like "v3.0.0"), trimmed. Returns 1 if missing.
read_plain_version() {
  local f="$1"
  [[ -f "${f}" ]] || return 1
  tr -d '[:space:]' < "${f}"
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
    --skip-skills)
      SKIP_SKILLS=1
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

# Auto-detect branch from piped URL if not explicitly set
if [[ "${BRANCH}" == "main" ]]; then
  if [[ -n "${RUBBER_DUCK_SOURCE_URL:-}" ]] && [[ "${RUBBER_DUCK_SOURCE_URL}" =~ githubusercontent\.com/[^/]+/[^/]+/([^/]+)/ ]]; then
    DETECTED_BRANCH="${BASH_REMATCH[1]}"
    if [[ "${DETECTED_BRANCH}" != "main" ]]; then
      BRANCH="${DETECTED_BRANCH}"
      log "Auto-detected branch: ${BRANCH}"
    fi
  fi
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

# Default RAW_BASE from branch if not explicitly set via --raw-base
if [[ -z "${RAW_BASE}" ]]; then
  RAW_BASE="https://raw.githubusercontent.com/sprngr/rubber-duck/${BRANCH}"
fi
if [[ "${BRANCH}" != "main" ]]; then
  log "Using branch: ${BRANCH}"
fi

if (( PRUNE == 1 )) && [[ "${ACTION}" != "sync" ]]; then
  err "--prune is only valid with sync"
  exit 1
fi

HAS_CLAUDE=0
for T in "${TARGETS[@]}"; do
  [[ "${T}" == "claude" ]] && HAS_CLAUDE=1
done

MANIFEST_PATH="$(manifest_path)"

running_piped() {
  [[ "${0:-}" == "bash" || "${0:-}" == "sh" || "${0:-}" == "-" ]]
}

if [[ "${ACTION}" == "sync" ]]; then
  if [[ ! -f "${MANIFEST_PATH}" ]]; then
    err "manifest missing: ${MANIFEST_PATH}. Run install first."
    exit 1
  fi
  if running_piped; then
    err "sync requires file-backed execution (not piped)"
    exit 1
  fi
  check_rawbase_allowed "${RAW_BASE}" "$(rawbase_check_mode)" || { err "rawBase not in allowlist: ${RAW_BASE}. Use --allow-untrusted-source to override."; exit 1; }
  manifest_load "${MANIFEST_PATH}"
  SYNC_TARGETS=()
  for T in "${MF_TARGET_NAMES[@]}"; do
    sync_enabled="${MF_TARGET_ENABLED[$T]:-true}"
    [[ "${sync_enabled}" == "true" ]] && SYNC_TARGETS+=("${T}")
  done
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
    declare -a SYNC_GROUP_KEYS=()
    declare -A SYNC_GROUP_TARGETS=()

    for T in "${SYNC_TARGETS[@]}"; do
      t_install_skills="${MF_TARGET_INSTALL_SKILLS[$T]:-true}"
      t_install_agents_md="${MF_TARGET_INSTALL_AGENTS_MD[$T]:-true}"
      t_extras="${MF_TARGET_EXTRAS[$T]:-false}"
      group_key="${t_install_skills}|${t_install_agents_md}|${t_extras}"

      if [[ -z "${SYNC_GROUP_TARGETS[$group_key]+x}" ]]; then
        SYNC_GROUP_KEYS+=("${group_key}")
        SYNC_GROUP_TARGETS["${group_key}"]="${T}"
      else
        SYNC_GROUP_TARGETS["${group_key}"]+=",${T}"
      fi
    done

    for group_key in "${SYNC_GROUP_KEYS[@]}"; do
      IFS='|' read -r g_install_skills g_install_agents_md g_extras <<< "${group_key}"
      group_harness_csv="${SYNC_GROUP_TARGETS[$group_key]}"

      sync_replay_cmd install "${group_harness_csv}" "${g_install_skills}" "${g_install_agents_md}" "${g_extras}"
      "${CMD[@]}"
    done
  fi

  if (( PRUNE == 1 )); then
    for T in opencode copilot claude; do
      if [[ -z "${SYNC_TARGET_SET[${T}]+x}" ]]; then
        sync_replay_cmd uninstall "${T}"
        "${CMD[@]}"
      fi
    done
  fi
  log "sync: complete"
  exit 0
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
      if [[ -d "${REPO_ROOT}/dist/opencode/agents" ]]; then
        LOCAL_AGENTS_DIR="${REPO_ROOT}/dist/opencode/agents"
      else
        LOCAL_AGENTS_DIR="${REPO_ROOT}/agents"
      fi
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
      if [[ -d "${REPO_ROOT}/dist/copilot/agents" ]]; then
        LOCAL_AGENTS_DIR="${REPO_ROOT}/dist/copilot/agents"
      else
        LOCAL_AGENTS_DIR="${REPO_ROOT}/agents"
      fi
      REMOTE_AGENTS_PATH="dist/copilot/agents"
      ;;
    claude)
      if (( PROJECT_SCOPE == 1 )); then
        DEST_AGENTS_DIR="${CLAUDE_PROJECT_AGENTS_DIR}"
        DEST_POLICY_MD="${CLAUDE_PROJECT_POLICY_MD}"
      else
        DEST_AGENTS_DIR="${CLAUDE_AGENTS_DIR}"
        DEST_POLICY_MD="${CLAUDE_POLICY_MD}"
      fi
      DEST_CLAUDE_AGENTS_MD="$(dirname -- "${DEST_POLICY_MD}")/AGENTS.md"
      POLICY_MODE="file"
      LOCAL_POLICY_FILE="${REPO_ROOT}/dist/claude/CLAUDE.md"
      LOCAL_AGENTS_DIR="${REPO_ROOT}/dist/claude/agents"
      REMOTE_POLICY_PATH="dist/claude/CLAUDE.md"
      REMOTE_AGENTS_PATH="dist/claude/agents"
      ;;
    *)
      err "invalid target: ${TARGET}"
      exit 1
      ;;
  esac
}

has_local_sources() {
  if [[ "${POLICY_MODE}" == "file" ]]; then
    [[ -f "${LOCAL_POLICY_FILE}" ]] || return 1
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

# Generate the AGENTS.md managed block content inline.
# This is a version marker — policy content lives in the agent body.
generate_agents_md() {
  local out="$1"
  local version="${CANONICAL_VERSION:-unknown}"
  cat > "${out}" <<EOF
<!-- RUBBER_DUCK_VERSION: ${version} -->
<!-- Policy content lives in the rubber-duck agent body. -->
<!-- This file is a version marker for sync and install workflows. -->
EOF
}

prepare_sources() {
  TMP_DIR="$(mktemp -d)"
  trap 'rm -rf "${TMP_DIR}"' EXIT

  if [[ "${EFFECTIVE_SOURCE}" == "local" ]]; then
    if ! has_local_sources; then
      err "local source selected but repo artifacts not found. Use --source web or run from repo checkout."
      exit 1
    fi
    if v="$(read_plain_version "${REPO_ROOT}/VERSION" 2>/dev/null)"; then
      CANONICAL_VERSION="${v}"
    fi
    generate_agents_md "${TMP_DIR}/AGENTS.md"
    if [[ "${POLICY_MODE}" == "file" ]]; then
      cp -f "${LOCAL_POLICY_FILE}" "${TMP_DIR}/CLAUDE.md"
    fi
    for f in "${AGENT_FILES[@]}"; do
      cp -f "${LOCAL_AGENTS_DIR}/${f}" "${TMP_DIR}/${f}"
    done
    return
  fi

  require_cmd curl
  # Fetch remote VERSION to embed in generated managed block.
  if v="$(curl -fsSL "${RAW_BASE}/VERSION" 2>/dev/null)"; then
    CANONICAL_VERSION="${v}"
  fi
  generate_agents_md "${TMP_DIR}/AGENTS.md"
  if [[ "${POLICY_MODE}" == "file" ]]; then
    curl -fsSL "${RAW_BASE}/${REMOTE_POLICY_PATH}" -o "${TMP_DIR}/CLAUDE.md"
  fi
  for f in "${AGENT_FILES[@]}"; do
    curl -fsSL "${RAW_BASE}/${REMOTE_AGENTS_PATH}/${f}" -o "${TMP_DIR}/${f}"
  done
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
  local target="${1:-${DEST_POLICY_MD}}"
  local content_file="${2:-${TMP_DIR}/AGENTS.md}"
  if (( DRY_RUN == 1 )); then
    log "[dry-run] upsert managed block in ${target}"
    return
  fi
  mkdir -p "$(dirname -- "${target}")"
  touch "${target}"
  # Prune existing managed block before writing new one.
  # This handles 2.x→3.x migration where old blocks are larger.
  if grep -Fq "${MANAGED_START}" "${target}" 2>/dev/null; then
    log "Pruning existing managed block from ${target}"
  fi
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

sync_wrapper_path() {
  if (( PROJECT_SCOPE == 1 )); then
    printf '.rubber-duck/sync-latest.sh'
  else
    printf '%s/.config/rubber-duck/sync-latest.sh' "${HOME}"
  fi
}

install_sync_wrapper() {
  local target scope_flag tmp src_tpl installer_url
  target="$(sync_wrapper_path)"
  scope_flag="--project"
  (( PROJECT_SCOPE == 0 )) && scope_flag="--global"

  if (( DRY_RUN == 1 )); then
    log "[dry-run] write sync helper -> ${target}"
    return 0
  fi

  mkdir -p "$(dirname -- "${target}")"
  tmp="$(mktemp)"
  if [[ "${EFFECTIVE_SOURCE}" == "local" ]]; then
    installer_url="${SCRIPT_PATH}"
  else
    installer_url="${RAW_BASE}/scripts/rubber-duck.sh"
  fi
  if [[ "${EFFECTIVE_SOURCE}" == "local" ]]; then
    src_tpl="${REPO_ROOT}/dist/scripts/sync-latest.sh"
    [[ -f "${src_tpl}" ]] || { err "missing sync wrapper template: ${src_tpl}. Run make build-harness."; rm -f "${tmp}"; exit 1; }
    cp -f "${src_tpl}" "${tmp}"
  else
    if ! curl -fsSL "${RAW_BASE}/${SYNC_WRAPPER_TEMPLATE_REMOTE}" -o "${tmp}"; then
      err "missing sync wrapper template: ${RAW_BASE}/${SYNC_WRAPPER_TEMPLATE_REMOTE}. Run make build-harness."
      rm -f "${tmp}"
      exit 1
    fi
  fi
  sed -i "s|{{SYNC_SCOPE_FLAG}}|${scope_flag}|g" "${tmp}"
  sed -i "s|{{SYNC_INSTALLER_URL}}|${installer_url}|g" "${tmp}"
  chmod +x "${tmp}"
  mv "${tmp}" "${target}"
  log "Installed sync helper -> ${target}"
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
  local installed=0 skipped=0
  for f in "${AGENT_FILES[@]}"; do
    if [[ -f "${DEST_AGENTS_DIR}/${f}" ]]; then
      local tmp_h dest_h
      tmp_h=$(compute_sha256 "${TMP_DIR}/${f}")
      dest_h=$(compute_sha256 "${DEST_AGENTS_DIR}/${f}")
      if [[ -n "${tmp_h}" && "${tmp_h}" == "${dest_h}" ]]; then
        skipped=$((skipped + 1))
        continue
      fi
    fi
    cp -f "${TMP_DIR}/${f}" "${DEST_AGENTS_DIR}/${f}"
    installed=$((installed + 1))
  done
  log "Installed ${installed} agents (${skipped} unchanged) -> ${DEST_AGENTS_DIR}"
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
  local -a agent_args=()
  for a in "$@"; do agent_args+=(-a "${a}"); done
  if (( DRY_RUN == 1 )); then
    log "[dry-run] npx ${SKILLS_CLI} add ${SKILLS_SOURCE} --skill ${install_list[*]} ${agent_args[*]} ${scope} -y"
    return
  fi
  if ! command -v npx >/dev/null 2>&1; then
    warn "npx not found; skipping skills install"
    return
  fi
  npx "${SKILLS_CLI}" add "${SKILLS_SOURCE}" --skill ${install_list[*]} ${agent_args[*]} ${scope} -y
}

skills_uninstall() {
  (( SKIP_SKILLS == 1 )) && return 0
  local scope=""
  local -a all_skills=("${DEFAULT_SKILLS[@]}" "${EXTRAS_SKILLS[@]}")
  (( PROJECT_SCOPE == 0 )) && scope="-g"
  local -a agent_args=()
  for a in "$@"; do agent_args+=(-a "${a}"); done
  if (( DRY_RUN == 1 )); then
    log "[dry-run] npx ${SKILLS_CLI} remove ${SKILLS_SOURCE} --skill ${all_skills[*]} ${agent_args[*]} ${scope} -y"
    return
  fi
  if ! command -v npx >/dev/null 2>&1; then
    warn "npx not found; skipping skills uninstall"
    return
  fi
  if ! npx "${SKILLS_CLI}" remove "${SKILLS_SOURCE}" --skill ${all_skills[*]} ${agent_args[*]} ${scope} -y; then
    warn "skills remove failed; remove package manually if needed"
  fi
}

# Map our target names to skills CLI agent identifiers.
target_to_skills_agent() {
  case "$1" in
    opencode) printf 'opencode' ;;
    copilot)  printf 'github-copilot' ;;
    claude)   printf 'claude-code' ;;
    *)        printf '' ;;
  esac
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
  has_managed_block "${target}" && state="present"
  log "AGENTS policy block (${target##*/}): ${state}"
}

status() {
  if v="$(extract_version_from_file "${DEST_POLICY_MD}" 2>/dev/null)"; then
    CANONICAL_VERSION="${v}"
  fi
  log "agents_dir: ${DEST_AGENTS_DIR}"
  log "policy_md: ${DEST_POLICY_MD}"
  local installed=0
  for f in "${AGENT_FILES[@]}"; do
    [[ -f "${DEST_AGENTS_DIR}/${f}" ]] && installed=$((installed + 1))
  done
  log "agents: ${installed}/${#AGENT_FILES[@]} present"
  report_policy_block "${DEST_POLICY_MD}"
  [[ "${POLICY_MODE}" == "file" ]] && report_policy_block "${DEST_CLAUDE_AGENTS_MD}"
  return 0
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
}

manifest_update_target() {
  local op="$1" target_name="$2"
  (( DRY_RUN == 1 )) && { log "[dry-run] manifest ${op} ${target_name} -> ${MANIFEST_PATH}"; return 0; }
  local prior_version=""
  prior_version=$(read_prior_version "${MANIFEST_PATH}")
  warn_on_downgrade "${prior_version}" "${CANONICAL_VERSION}"
  local template_path="${REPO_ROOT}/${MANIFEST_TEMPLATE_PATH}"
  manifest_load "${MANIFEST_PATH}" "${template_path}"
  MF_SOURCE_MODE="${EFFECTIVE_SOURCE}"
  MF_SOURCE_REF="${BRANCH}"
  MF_SOURCE_RAW_BASE="${RAW_BASE}"
  MF_SOURCE_LAST_APPLIED_VERSION="${CANONICAL_VERSION}"
  if [[ "${op}" == "install" ]]; then
    local found=0 t
    for t in "${MF_TARGET_NAMES[@]}"; do
      [[ "${t}" == "${target_name}" ]] && { found=1; break; }
    done
    (( found == 0 )) && MF_TARGET_NAMES+=("${target_name}")
    MF_TARGET_ENABLED["${target_name}"]="true"
    if (( PROJECT_SCOPE == 1 )); then MF_TARGET_SCOPE["${target_name}"]="project"
    else MF_TARGET_SCOPE["${target_name}"]="global"; fi
    MF_TARGET_INSTALL_AGENTS_MD["${target_name}"]="true"
    if (( SKIP_SKILLS == 1 )); then MF_TARGET_INSTALL_SKILLS["${target_name}"]="false"
    else MF_TARGET_INSTALL_SKILLS["${target_name}"]="true"; fi
    if (( EXTRAS == 1 )); then MF_TARGET_EXTRAS["${target_name}"]="true"
    else MF_TARGET_EXTRAS["${target_name}"]="false"; fi
  elif [[ "${op}" == "uninstall" ]]; then
    unset "MF_TARGET_ENABLED[${target_name}]"
    unset "MF_TARGET_SCOPE[${target_name}]"
    unset "MF_TARGET_INSTALL_AGENTS_MD[${target_name}]"
    unset "MF_TARGET_INSTALL_SKILLS[${target_name}]"
    unset "MF_TARGET_EXTRAS[${target_name}]"
    local -a new_names=() t
    for t in "${MF_TARGET_NAMES[@]}"; do
      [[ "${t}" != "${target_name}" ]] && new_names+=("${t}")
    done
    MF_TARGET_NAMES=("${new_names[@]}")
  fi
  manifest_save "${MANIFEST_PATH}"
}

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

check_rawbase_allowed "${RAW_BASE}" "$(rawbase_check_mode)" || { err "rawBase not in allowlist: ${RAW_BASE}. Use --allow-untrusted-source to override."; exit 1; }

# Pre-loop header (install/uninstall only)
if [[ "${ACTION}" == "install" || "${ACTION}" == "uninstall" ]]; then
  [[ "${ACTION}" == "install" ]] && print_banner
  resolve_canonical_version
  log "version: ${CANONICAL_VERSION}"
  if [[ "${EFFECTIVE_SOURCE}" == "local" ]]; then
    log "source: local (${REPO_ROOT})"
  else
    log "source: web (${RAW_BASE})"
  fi
  log "doctor: ok"
fi

# Consolidated skills call: one npx invocation with -a for each selected target.
if [[ "${ACTION}" == "install" || "${ACTION}" == "uninstall" ]] && (( ${#TARGETS[@]} > 0 )); then
  SKILLS_AGENTS=()
  for T in "${TARGETS[@]}"; do
    a=$(target_to_skills_agent "${T}")
    [[ -n "${a}" ]] && SKILLS_AGENTS+=("${a}")
  done
  if (( ${#SKILLS_AGENTS[@]} > 0 )); then
    if [[ "${ACTION}" == "install" ]]; then
      skills_install "${SKILLS_AGENTS[@]}"
    else
      skills_uninstall "${SKILLS_AGENTS[@]}"
    fi
    skills_status
  fi
fi

for TARGET in "${TARGETS[@]}"; do
  resolve_target

  case "${ACTION}" in
    install|uninstall) log ""; log "[${TARGET}]" ;;
  esac

  case "${ACTION}" in
    install)
      doctor
      prepare_sources
      install_agents
      if (( SYNC_WRAPPER_WRITTEN == 0 )); then
        install_sync_wrapper
        SYNC_WRAPPER_WRITTEN=1
      fi
      backup_md "${DEST_POLICY_MD}"
      if [[ "${POLICY_MODE}" == "managed_block" ]]; then
        upsert_managed_block
      else
        backup_md "${DEST_CLAUDE_AGENTS_MD}"
        install_policy_file
      fi
      status
      manifest_update_target "install" "${TARGET}"
      PIN_PAIRS=()
      for pin_f in "${AGENT_FILES[@]}"; do
        pin_h=$(compute_sha256 "${TMP_DIR}/${pin_f}") && PIN_PAIRS+=("$(agent_remote_pin_key "${pin_f}")=${pin_h}")
      done
      pin_policy="${TMP_DIR}/AGENTS.md"
      pin_path="managed-block"
      if [[ "${POLICY_MODE}" == "file" ]]; then
        pin_policy="${TMP_DIR}/CLAUDE.md"
        pin_path="${REMOTE_POLICY_PATH}"
      fi
      pin_h=$(compute_sha256 "${pin_policy}") && PIN_PAIRS+=("${pin_path}=${pin_h}")
      write_pins "${MANIFEST_PATH}" "${PIN_PAIRS[@]}"
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

if [[ "${ACTION}" == "install" || "${ACTION}" == "uninstall" ]]; then
  log ""
  log "🦆 quack"
  if [[ "${ACTION}" == "install" ]]; then
    if (( PROJECT_SCOPE == 1 )); then
      log "To update: bash .rubber-duck/sync-latest.sh"
    else
      log "To update: bash ${HOME}/.config/rubber-duck/sync-latest.sh"
    fi
  fi
fi
