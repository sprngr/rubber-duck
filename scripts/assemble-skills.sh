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

SKILL_NAME="duck-debug"
SRC_DIR="${REPO_ROOT}/src/skills/${SKILL_NAME}"
OUT_DIR="${REPO_ROOT}/skills/${SKILL_NAME}"

if [[ ! -d "${SRC_DIR}" ]]; then
  printf 'ERROR: missing source dir: %s\n' "${SRC_DIR}" >&2
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

failed=0
copy_or_check "${SRC_DIR}/SKILL.md" "${OUT_DIR}/SKILL.md" || failed=1
copy_or_check "${SRC_DIR}/references/GUARDRAILS.md" "${OUT_DIR}/references/GUARDRAILS.md" || failed=1

if (( failed != 0 )); then
  exit 1
fi

printf 'assemble-skills: %s (%s)\n' "${SKILL_NAME}" "$([[ ${CHECK_ONLY} -eq 1 ]] && printf 'check' || printf 'build')"
