#!/usr/bin/env bash
set -euo pipefail

CHECK_ONLY=0
if [[ "${1:-}" == "--check" ]]; then
  CHECK_ONLY=1
elif [[ $# -gt 0 ]]; then
  printf 'Usage: %s [--check]\n' "${0}" >&2
  exit 1
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${0}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
RULES_FILE="${REPO_ROOT}/build/skill-assembly.rules.json"

SRC_ROOT="${REPO_ROOT}/src/skills"
OUT_ROOT="${REPO_ROOT}/skills"
CANONICAL_GUARDRAILS="${REPO_ROOT}/src/shared/references/GUARDRAILS.md"
SKILL_SNIPPETS_ROOT="${REPO_ROOT}/src/shared/skill-snippets"
POLICY_SNIPPETS_ROOT="${REPO_ROOT}/src/shared/policy-snippets"

# rsync mirrors src/skills/ -> skills/ for raw assets.
# --checksum: compare file content (not mtime+size). Matches cmp-based check semantics.
# --no-times: ignore timestamp-only differences. Prevents false drift on cp'd files.
# --delete: prune orphan files and orphan skill dirs in mirror.
# Excludes: SKILL.md (rendered separately), references/GUARDRAILS.md (injected from canonical source),
# evals/ (src-only, not shipped in built artifacts).
RSYNC_FLAGS=(
  -a --checksum --no-times --delete --itemize-changes
  --exclude='SKILL.md'
  --exclude='references/GUARDRAILS.md'
  --exclude='evals/'
)

if [[ ! -d "${SRC_ROOT}" ]]; then
  printf 'ERROR: missing source root: %s\n' "${SRC_ROOT}" >&2
  exit 1
fi

if [[ ! -f "${CANONICAL_GUARDRAILS}" ]]; then
  printf 'ERROR: missing canonical guardrails: %s\n' "${CANONICAL_GUARDRAILS}" >&2
  exit 1
fi

# ===== Render pipeline ({{include}} resolution) =====

append_include_if_match() {
  local line="$1"
  local out="$2"

  if [[ "${line}" =~ ^[[:space:]]*\{\{include:[[:space:]]*skill-snippets/([^[:space:]\}]+)[[:space:]]*\}\}[[:space:]]*$ ]]; then
    local snippet_name="${BASH_REMATCH[1]}"
    local snippet_path="${SKILL_SNIPPETS_ROOT}/${snippet_name}"
    if [[ ! -f "${snippet_path}" ]]; then
      printf 'ERROR: missing skill snippet: %s\n' "${snippet_path}" >&2
      return 2
    fi
    cat "${snippet_path}" >> "${out}"
    printf '\n' >> "${out}"
    return 0
  fi

  if [[ "${line}" =~ ^[[:space:]]*\{\{include:[[:space:]]*policy-snippets/([^[:space:]\}]+)[[:space:]]*\}\}[[:space:]]*$ ]]; then
    local snippet_name="${BASH_REMATCH[1]}"
    local snippet_path="${POLICY_SNIPPETS_ROOT}/${snippet_name}"
    if [[ ! -f "${snippet_path}" ]]; then
      printf 'ERROR: missing policy snippet: %s\n' "${snippet_path}" >&2
      return 2
    fi
    cat "${snippet_path}" >> "${out}"
    printf '\n' >> "${out}"
    return 0
  fi

  return 1
}

render_skill_markdown() {
  local src="$1"
  local out="$2"
  local line=""
  local include_status=0

  if [[ ! -f "${src}" ]]; then
    printf 'ERROR: missing source file: %s\n' "${src}" >&2
    return 1
  fi

  mkdir -p "$(dirname -- "${out}")"
  : > "${out}"

  while IFS= read -r line || [[ -n "${line}" ]]; do
    include_status=0
    append_include_if_match "${line}" "${out}" || include_status=$?
    if (( include_status == 0 )); then
      continue
    fi
    if (( include_status == 2 )); then
      rm -f "${out}"
      return 1
    fi

    printf '%s\n' "${line}" >> "${out}"
  done < "${src}"

  return 0
}

# ===== Rule checks =====

load_deny_tokens() {
  local rules_file="$1"
  if [[ ! -f "${rules_file}" ]]; then
    printf 'ERROR: missing rules file: %s\n' "${rules_file}" >&2
    return 1
  fi

  mapfile -t DENY_TOKENS < <(
    python3 - "${rules_file}" <<'PY'
import json
import sys

path = sys.argv[1]
with open(path, "r", encoding="utf-8") as f:
    data = json.load(f)

tokens = []
for inv in data.get("invariants", []):
    for token in inv.get("deny_tokens", []):
        tokens.append(token)

for token in tokens:
    print(token)
PY
  )

  if (( ${#DENY_TOKENS[@]} == 0 )); then
    printf 'ERROR: no deny tokens loaded from %s\n' "${rules_file}" >&2
    return 1
  fi

  return 0
}

check_portability() {
  local file_path="$1"
  local line_no=0

  while IFS= read -r line || [[ -n "${line}" ]]; do
    line_no=$((line_no + 1))
    for token in "${DENY_TOKENS[@]}"; do
      [[ -n "${token}" ]] || continue
      if [[ "${line}" == *"${token}"* ]]; then
        printf 'PORTABILITY: %s:%d contains denied token: %s\n' "${file_path}" "${line_no}" "${token}" >&2
        return 1
      fi
    done
  done < "${file_path}"

  return 0
}

enforce_rule_checks() {
  local rules_file="$1"
  local repo_root="$2"

  python3 "${REPO_ROOT}/scripts/lib/check-rules.py" \
    "${rules_file}" \
    "${repo_root}" \
    --groups-key skill_groups \
    --group-file-template 'src/skills/{item}/SKILL.md'
}

# ===== Mirror raw assets via rsync =====
# Mirrors references/, assets/, examples/, hooks/, README.md from src/skills/ -> skills/.
# --delete prunes orphan files within valid skill dirs.
# Orphan skill dirs (whole dir not in src) handled separately after rsync,
# because excluded references/GUARDRAILS.md prevents rsync --delete from removing parent dir.

mirror_or_check_assets() {
  local output
  local filtered
  local rc=0

  if (( CHECK_ONLY == 1 )); then
    output="$(rsync "${RSYNC_FLAGS[@]}" --dry-run "${SRC_ROOT}/" "${OUT_ROOT}/" 2>&1)" || rc=$?
    if (( rc != 0 )); then
      printf 'ERROR: rsync check failed (rc=%d):\n%s\n' "${rc}" "${output}" >&2
      return 1
    fi
    # Filter to real changes only: *deleting (orphans), >f (file updates), cd (new dirs).
    # Ignore cosmetic noise: "cannot delete non-empty directory", ".d..t" (timestamp-only).
    filtered="$(printf '%s\n' "${output}" | grep -E '^\*deleting|^>f|^cd' || true)"
    if [[ -n "${filtered}" ]]; then
      printf 'STALE: mirror drift detected:\n' >&2
      printf '%s\n' "${filtered}" >&2
      return 1
    fi
    return 0
  fi

  output="$(rsync "${RSYNC_FLAGS[@]}" "${SRC_ROOT}/" "${OUT_ROOT}/" 2>&1)" || rc=$?
  if (( rc != 0 )); then
    printf 'ERROR: rsync build failed (rc=%d):\n%s\n' "${rc}" "${output}" >&2
    return 1
  fi
  filtered="$(printf '%s\n' "${output}" | grep -E '^\*deleting|^>f|^cd' || true)"
  if [[ -n "${filtered}" ]]; then
    printf '%s\n' "${filtered}" | while IFS= read -r line; do
      case "${line}" in
        "*deleting"*)
          printf 'Pruned: %s\n' "${line:12}"
          ;;
        ">"*|"cd"*)
          printf 'Built: %s\n' "${line:12}"
          ;;
      esac
    done
  fi
  return 0
}

# ===== Remove orphan skill dirs =====
# rsync --delete can't remove skill dirs containing excluded files (references/GUARDRAILS.md).
# Separate pass: any dir in skills/ without a matching dir in src/skills/ is an orphan.

prune_or_check_orphan_skill_dirs() {
  local out_skill
  local skill_name

  shopt -s nullglob
  for out_skill in "${OUT_ROOT}"/*; do
    [[ -d "${out_skill}" ]] || continue
    skill_name="$(basename -- "${out_skill}")"
    if [[ ! -d "${SRC_ROOT}/${skill_name}" ]]; then
      if (( CHECK_ONLY == 1 )); then
        printf 'STALE: orphan skill dir: %s\n' "${out_skill}" >&2
        return 1
      else
        rm -rf "${out_skill}"
        printf 'Pruned: %s\n' "${out_skill}"
      fi
    fi
  done
  shopt -u nullglob
  return 0
}

# ===== Render or check SKILL.md per skill =====

render_or_check_skill() {
  local src="$1"
  local out="$2"
  local tmp

  tmp="$(mktemp)"
  if ! render_skill_markdown "${src}" "${tmp}"; then
    rm -f "${tmp}"
    return 1
  fi

  if (( CHECK_ONLY == 1 )); then
    if [[ ! -f "${out}" ]]; then
      printf 'MISSING: %s\n' "${out}" >&2
      rm -f "${tmp}"
      return 1
    fi
    if ! cmp -s "${tmp}" "${out}"; then
      printf 'STALE: %s\n' "${out}" >&2
      rm -f "${tmp}"
      return 1
    fi
    printf 'Checked: %s\n' "${out}"
    rm -f "${tmp}"
    return 0
  fi

  mkdir -p "$(dirname -- "${out}")"
  cp -f "${tmp}" "${out}"
  printf 'Built: %s\n' "${out}"
  rm -f "${tmp}"
}

# ===== Inject or check canonical GUARDRAILS.md per skill =====

inject_or_check_guardrails() {
  local out="$1"

  if (( CHECK_ONLY == 1 )); then
    if [[ ! -f "${out}" ]]; then
      printf 'MISSING: %s\n' "${out}" >&2
      return 1
    fi
    if ! cmp -s "${CANONICAL_GUARDRAILS}" "${out}"; then
      printf 'STALE: %s\n' "${out}" >&2
      return 1
    fi
    printf 'Checked: %s\n' "${out}"
    return 0
  fi

  mkdir -p "$(dirname -- "${out}")"
  cp -f "${CANONICAL_GUARDRAILS}" "${out}"
  printf 'Built: %s\n' "${out}"
}

# ===== Main =====

failed=0

if (( CHECK_ONLY == 1 )); then
  load_deny_tokens "${RULES_FILE}" || exit 1
  enforce_rule_checks "${RULES_FILE}" "${REPO_ROOT}" || exit 1
fi

shopt -s nullglob
SKILL_DIRS=("${SRC_ROOT}"/*)

if (( ${#SKILL_DIRS[@]} == 0 )); then
  printf 'ERROR: no skills found under %s\n' "${SRC_ROOT}" >&2
  exit 1
fi

# 1. Mirror raw assets (rsync handles orphan file deletion within valid skill dirs)
mirror_or_check_assets || failed=1

# 2. Remove orphan skill dirs (rsync can't remove dirs containing excluded GUARDRAILS.md)
prune_or_check_orphan_skill_dirs || failed=1

# 3. Portability check on canonical GUARDRAILS (once, not per-skill)
if (( CHECK_ONLY == 1 )); then
  check_portability "${CANONICAL_GUARDRAILS}" || failed=1
fi

# 3. Per-skill: render SKILL.md, inject GUARDRAILS.md, portability checks on src assets
processed=0
for src_dir in "${SKILL_DIRS[@]}"; do
  [[ -d "${src_dir}" ]] || continue
  [[ -f "${src_dir}/SKILL.md" ]] || continue
  skill_name="$(basename -- "${src_dir}")"
  out_dir="${OUT_ROOT}/${skill_name}"

  if (( CHECK_ONLY == 1 )); then
    check_portability "${src_dir}/SKILL.md" || failed=1
  fi
  render_or_check_skill "${src_dir}/SKILL.md" "${out_dir}/SKILL.md" || failed=1

  inject_or_check_guardrails "${out_dir}/references/GUARDRAILS.md" || failed=1

  # Portability checks on src asset files (references, assets, examples, hooks, README.md)
  if (( CHECK_ONLY == 1 )); then
    for sub in references assets examples hooks; do
      [[ -d "${src_dir}/${sub}" ]] || continue
      shopt -s globstar
      for asset in "${src_dir}"/${sub}/**; do
        [[ -f "${asset}" ]] || continue
        [[ "$(basename -- "${asset}")" == "GUARDRAILS.md" ]] && continue
        check_portability "${asset}" || failed=1
      done
      shopt -u globstar
    done
    if [[ -f "${src_dir}/README.md" ]]; then
      check_portability "${src_dir}/README.md" || failed=1
    fi
  fi

  processed=$((processed + 1))
done

shopt -u nullglob

if (( failed != 0 )); then
  exit 1
fi

printf 'assemble-skills: %s skills (%s)\n' "${processed}" "$([[ ${CHECK_ONLY} -eq 1 ]] && printf 'check' || printf 'build')"
