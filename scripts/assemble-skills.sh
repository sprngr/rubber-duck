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
RULES_FILE="${REPO_ROOT}/build/skill-assembly/rules.json"

SRC_ROOT="${REPO_ROOT}/src/skills"
OUT_ROOT="${REPO_ROOT}/skills"
CANONICAL_GUARDRAILS="${REPO_ROOT}/src/shared/references/GUARDRAILS.md"
SKILL_SNIPPETS_ROOT="${REPO_ROOT}/src/shared/skill-snippets"
POLICY_SNIPPETS_ROOT="${REPO_ROOT}/src/shared/policy-snippets"

if [[ ! -d "${SRC_ROOT}" ]]; then
  printf 'ERROR: missing source root: %s\n' "${SRC_ROOT}" >&2
  exit 1
fi

if [[ ! -f "${CANONICAL_GUARDRAILS}" ]]; then
  printf 'ERROR: missing canonical guardrails: %s\n' "${CANONICAL_GUARDRAILS}" >&2
  exit 1
fi

copy_or_check() {
  local src="$1"
  local out="$2"

  if [[ ! -f "${src}" ]]; then
    printf 'ERROR: missing source file: %s\n' "${src}" >&2
    return 1
  fi

  if (( CHECK_ONLY == 1 )); then
    if [[ ! -f "${out}" ]]; then
      printf 'MISSING: %s\n' "${out}" >&2
      return 1
    fi
    if ! cmp -s "${src}" "${out}"; then
      printf 'STALE: %s\n' "${out}" >&2
      return 1
    fi
    printf 'Checked: %s\n' "${out}"
    return 0
  fi

  mkdir -p "$(dirname -- "${out}")"
  cp -f "${src}" "${out}"
  printf 'Built: %s\n' "${out}"
}

render_skill_markdown() {
  local src="$1"
  local out="$2"
  local line=""

  if [[ ! -f "${src}" ]]; then
    printf 'ERROR: missing source file: %s\n' "${src}" >&2
    return 1
  fi

  mkdir -p "$(dirname -- "${out}")"
  : > "${out}"

  while IFS= read -r line || [[ -n "${line}" ]]; do
    if [[ "${line}" =~ ^[[:space:]]*\{\{include:[[:space:]]*skill-snippets/([^[:space:]\}]+)[[:space:]]*\}\}[[:space:]]*$ ]]; then
      local snippet_name="${BASH_REMATCH[1]}"
      local snippet_path="${SKILL_SNIPPETS_ROOT}/${snippet_name}"
      if [[ ! -f "${snippet_path}" ]]; then
        printf 'ERROR: missing skill snippet: %s\n' "${snippet_path}" >&2
        rm -f "${out}"
        return 1
      fi
      cat "${snippet_path}" >> "${out}"
      printf '\n' >> "${out}"
      continue
    fi

    if [[ "${line}" =~ ^[[:space:]]*\{\{include:[[:space:]]*policy-snippets/([^[:space:]\}]+)[[:space:]]*\}\}[[:space:]]*$ ]]; then
      local snippet_name="${BASH_REMATCH[1]}"
      local snippet_path="${POLICY_SNIPPETS_ROOT}/${snippet_name}"
      if [[ ! -f "${snippet_path}" ]]; then
        printf 'ERROR: missing policy snippet: %s\n' "${snippet_path}" >&2
        rm -f "${out}"
        return 1
      fi
      cat "${snippet_path}" >> "${out}"
      printf '\n' >> "${out}"
      continue
    fi

    printf '%s\n' "${line}" >> "${out}"
  done < "${src}"

  return 0
}

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
  return 0
}

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

  python3 - "${rules_file}" "${repo_root}" <<'PY'
import json
import sys
from pathlib import Path

rules_path = Path(sys.argv[1])
repo_root = Path(sys.argv[2])

if not rules_path.exists():
    print(f"RULES: missing rules file: {rules_path}", file=sys.stderr)
    sys.exit(1)

with rules_path.open("r", encoding="utf-8") as f:
    data = json.load(f)

checks = data.get("checks", {})
required_files = checks.get("required_files", [])
text_assertions = checks.get("text_assertions", [])

errors = 0

for rel in required_files:
    target = repo_root / rel
    if not target.exists():
        print(f"RULES: missing required file: {rel}", file=sys.stderr)
        errors += 1

for idx, assertion in enumerate(text_assertions, start=1):
    file_rel = assertion.get("file")
    contains = assertion.get("contains")

    if not file_rel or contains is None:
        print(f"RULES: malformed text_assertion #{idx}", file=sys.stderr)
        errors += 1
        continue

    target = repo_root / file_rel
    if not target.exists():
        print(f"RULES: text_assertion file missing: {file_rel}", file=sys.stderr)
        errors += 1
        continue

    content = target.read_text(encoding="utf-8")
    if contains not in content:
        print(f"RULES: text_assertion failed: {file_rel} missing substring: {contains}", file=sys.stderr)
        errors += 1

if errors:
    sys.exit(1)
PY
}

failed=0

if (( CHECK_ONLY == 1 )); then
  load_deny_tokens "${RULES_FILE}" || exit 1
  enforce_rule_checks "${RULES_FILE}" "${REPO_ROOT}" || exit 1
fi

shopt -s nullglob
SKILL_DIRS=("${SRC_ROOT}"/duck-*)

if (( ${#SKILL_DIRS[@]} == 0 )); then
  printf 'ERROR: no duck-* skills found under %s\n' "${SRC_ROOT}" >&2
  exit 1
fi

processed=0
for src_dir in "${SKILL_DIRS[@]}"; do
  [[ -d "${src_dir}" ]] || continue
  skill_name="$(basename -- "${src_dir}")"
  out_dir="${OUT_ROOT}/${skill_name}"

  if (( CHECK_ONLY == 1 )); then
    check_portability "${src_dir}/SKILL.md" || failed=1
  fi
  render_or_check_skill "${src_dir}/SKILL.md" "${out_dir}/SKILL.md" || failed=1

  if [[ -d "${src_dir}/references" ]]; then
    shopt -s globstar
    for ref in "${src_dir}"/references/**; do
      [[ -f "${ref}" ]] || continue
      [[ "$(basename -- "${ref}")" == "GUARDRAILS.md" ]] && continue
      rel="${ref#${src_dir}/}"
      if (( CHECK_ONLY == 1 )); then
        check_portability "${ref}" || failed=1
      fi
      copy_or_check "${ref}" "${out_dir}/${rel}" || failed=1
    done
    shopt -u globstar
  fi

  if (( CHECK_ONLY == 1 )); then
    check_portability "${CANONICAL_GUARDRAILS}" || failed=1
  fi
  copy_or_check "${CANONICAL_GUARDRAILS}" "${out_dir}/references/GUARDRAILS.md" || failed=1

  processed=$((processed + 1))
done

shopt -u nullglob

if (( failed != 0 )); then
  exit 1
fi

printf 'assemble-skills: %s skills (%s)\n' "${processed}" "$([[ ${CHECK_ONLY} -eq 1 ]] && printf 'check' || printf 'build')"
