#!/usr/bin/env bash
set -euo pipefail

CHECK_ONLY=0
if [[ "${1:-}" == "--check" ]]; then
  CHECK_ONLY=1
elif [[ $# -gt 0 ]]; then
  printf 'Usage: %s [--check]\n' "${0}" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  printf 'ERROR: jq is required to render pi artifacts\n' >&2
  exit 1
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${0}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
SRC_AGENTS_DIR="${REPO_ROOT}/src/agents"
POLICY_SNIPPETS_DIR="${REPO_ROOT}/src/shared/policy-snippets"
PI_PACKAGE_AGENTS_DIR="${REPO_ROOT}/pi/agents"
ROOT_AGENTS_MD="${REPO_ROOT}/AGENTS.md"
RUBBER_DUCK_BODY_MD="${REPO_ROOT}/src/agents/rubber-duck/body.md"
PI_PACKAGE_AGENTS_MD="${REPO_ROOT}/pi/AGENTS.md"

render_or_check_file() {
  local tmp_path="$1"
  local out_path="$2"

  if (( CHECK_ONLY == 1 )); then
    if [[ ! -f "${out_path}" ]]; then
      printf 'MISSING: %s\n' "${out_path}" >&2
      return 1
    fi
    if ! cmp -s "${out_path}" "${tmp_path}"; then
      printf 'STALE: %s\n' "${out_path}" >&2
      return 1
    fi
    printf 'Checked: %s\n' "${out_path}"
    return 0
  fi

  mkdir -p "$(dirname -- "${out_path}")"
  cp -f "${tmp_path}" "${out_path}"
  printf 'Built: %s\n' "${out_path}"
}

ensure_absent() {
  local target="$1"

  if (( CHECK_ONLY == 1 )); then
    if [[ -e "${target}" ]]; then
      printf 'STALE: %s should not exist\n' "${target}" >&2
      return 1
    fi
    return 0
  fi

  if [[ -e "${target}" ]]; then
    rm -f "${target}"
    printf 'Removed: %s\n' "${target}"
  fi
}

append_policy_include_if_match() {
  local line="$1"
  local out="$2"

  if [[ "${line}" =~ ^[[:space:]]*\{\{include:[[:space:]]*policy-snippets/([^[:space:]\}]+)[[:space:]]*\}\}[[:space:]]*$ ]]; then
    local snippet_name="${BASH_REMATCH[1]}"
    local snippet_path="${POLICY_SNIPPETS_DIR}/${snippet_name}"
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

render_body_markdown() {
  local src="$1"
  local out="$2"
  local line=""
  local include_status=0

  if [[ ! -f "${src}" ]]; then
    printf 'ERROR: missing body source file: %s\n' "${src}" >&2
    return 1
  fi

  : > "${out}"

  while IFS= read -r line || [[ -n "${line}" ]]; do
    include_status=0
    append_policy_include_if_match "${line}" "${out}" || include_status=$?
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

map_tools_for_pi() {
  local claude_tools="$1"
  local -a ordered=()
  local token normalized mapped

  # shellcheck disable=SC2206
  local raw_tokens=( ${claude_tools//,/ } )
  for token in "${raw_tokens[@]}"; do
    normalized="$(printf '%s' "${token}" | tr '[:upper:]' '[:lower:]')"
    normalized="${normalized//[[:space:]]/}"

    mapped=""
    case "${normalized}" in
      read) mapped="read" ;;
      glob) mapped="find" ;;
      grep) mapped="grep" ;;
      bash) mapped="bash" ;;
      edit) mapped="edit" ;;
      write) mapped="write" ;;
      agent) mapped="subagent" ;;
      *) mapped="" ;;
    esac

    if [[ -n "${mapped}" ]]; then
      local seen=0
      for existing in "${ordered[@]}"; do
        if [[ "${existing}" == "${mapped}" ]]; then
          seen=1
          break
        fi
      done
      if (( seen == 0 )); then
        ordered+=("${mapped}")
      fi
    fi
  done

  local joined=""
  for mapped in "${ordered[@]}"; do
    if [[ -n "${joined}" ]]; then
      joined+=", "
    fi
    joined+="${mapped}"
  done

  printf '%s' "${joined}"
}

render_pi_frontmatter() {
  local meta="$1"
  local out="$2"
  local name description claude_tools pi_tools

  name="$(jq -r '.name' "${meta}")"
  description="$(jq -r '.description' "${meta}")"
  claude_tools="$(jq -r '.harnesses.claude.tools // ""' "${meta}")"
  pi_tools="$(map_tools_for_pi "${claude_tools}")"

  {
    printf -- '---\n'
    printf 'name: %s\n' "${name}"
    printf 'description: %s\n' "${description}"
    if [[ -n "${pi_tools}" ]]; then
      printf 'tools: %s\n' "${pi_tools}"
    fi
    printf -- '---\n\n'
  } > "${out}"
}

extract_markdown_section() {
  local file="$1"
  local heading="$2"

  awk -v start="${heading}" '
    BEGIN {
      level = 0
      in_section = 0
      if (match(start, /^#+/)) level = RLENGTH
    }
    {
      if ($0 == start) {
        in_section = 1
        print
        next
      }

      if (in_section) {
        if (match($0, /^#+ /)) {
          current_level = RLENGTH - 1
          if (current_level <= level) exit
        }
        print
      }
    }
  ' "${file}"
}

assemble_extension_agents_md() {
  local out="$1"

  {
    cat "${ROOT_AGENTS_MD}"
    printf '\n\n## Rubber Duck Extension Router Policy\n\n'
    printf '_Assembled from src/agents/rubber-duck/body.md. Use as deterministic extension policy context._\n\n'

    extract_markdown_section "${RUBBER_DUCK_BODY_MD}" "## Role"
    printf '\n'
    extract_markdown_section "${RUBBER_DUCK_BODY_MD}" "### Soft Preflight (before patching)"
    printf '\n'
    extract_markdown_section "${RUBBER_DUCK_BODY_MD}" "### Adaptive Decision Checkpoints (for mutating actions)"
    printf '\n'
    extract_markdown_section "${RUBBER_DUCK_BODY_MD}" "## Workflow"
  } > "${out}"
}

mkdir -p "${PI_PACKAGE_AGENTS_DIR}"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

if [[ ! -f "${ROOT_AGENTS_MD}" ]]; then
  printf 'ERROR: missing root AGENTS.md: %s\n' "${ROOT_AGENTS_MD}" >&2
  exit 1
fi
if [[ ! -f "${RUBBER_DUCK_BODY_MD}" ]]; then
  printf 'ERROR: missing router body: %s\n' "${RUBBER_DUCK_BODY_MD}" >&2
  exit 1
fi

ASSEMBLED_AGENTS_MD_RAW_TMP="${TMP_DIR}/pi-AGENTS.raw.md"
ASSEMBLED_AGENTS_MD_TMP="${TMP_DIR}/pi-AGENTS.md"
assemble_extension_agents_md "${ASSEMBLED_AGENTS_MD_RAW_TMP}"
render_body_markdown "${ASSEMBLED_AGENTS_MD_RAW_TMP}" "${ASSEMBLED_AGENTS_MD_TMP}"
render_or_check_file "${ASSEMBLED_AGENTS_MD_TMP}" "${PI_PACKAGE_AGENTS_MD}"

ensure_absent "${PI_PACKAGE_AGENTS_DIR}/rubber-duck.md"

CONFIG_AGENTS=()
if [[ -d "${SRC_AGENTS_DIR}" ]]; then
  for meta in "${SRC_AGENTS_DIR}"/*/meta.json; do
    [[ -e "${meta}" ]] || continue
    CONFIG_AGENTS+=("$(basename "$(dirname "${meta}")")")
  done
fi

if (( ${#CONFIG_AGENTS[@]} == 0 )); then
  printf 'ERROR: no agent configs found under %s\n' "${SRC_AGENTS_DIR}" >&2
  exit 1
fi

for name in "${CONFIG_AGENTS[@]}"; do
  if [[ "${name}" == "rubber-duck" ]]; then
    continue
  fi
  agent_dir="${SRC_AGENTS_DIR}/${name}"
  meta="${agent_dir}/meta.json"
  body="${agent_dir}/body.md"

  if [[ ! -f "${meta}" || ! -f "${body}" ]]; then
    printf 'ERROR: missing agent config files for %s under %s\n' "${name}" "${agent_dir}" >&2
    exit 1
  fi

  rendered_body="${TMP_DIR}/body-${name}.md"
  rendered_agent="${TMP_DIR}/pi-${name}.md"

  render_body_markdown "${body}" "${rendered_body}"
  render_pi_frontmatter "${meta}" "${rendered_agent}"
  cat "${rendered_body}" >> "${rendered_agent}"

  render_or_check_file "${rendered_agent}" "${PI_PACKAGE_AGENTS_DIR}/${name}.md"
done
