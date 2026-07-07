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
  printf 'ERROR: jq is required to render agent config (build-time only)\n' >&2
  exit 1
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${0}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
RULES_FILE="${REPO_ROOT}/build/agent-assembly.rules.json"

SRC_AGENTS_DIR="${REPO_ROOT}/src/agents"
POLICY_SNIPPETS_DIR="${REPO_ROOT}/src/shared/policy-snippets"

CLAUDE_DIST_DIR="${REPO_ROOT}/dist/claude"
CLAUDE_AGENT_DIR="${CLAUDE_DIST_DIR}/agents"
CLAUDE_MD_OUT="${CLAUDE_DIST_DIR}/CLAUDE.md"

OPENCODE_DIST_DIR="${REPO_ROOT}/dist/opencode"
OPENCODE_AGENT_DIR="${OPENCODE_DIST_DIR}/agents"

COPILOT_DIST_DIR="${REPO_ROOT}/dist/copilot"
COPILOT_AGENT_DIR="${COPILOT_DIST_DIR}/agents"

PI_DIST_DIR="${REPO_ROOT}/dist/pi"
PI_AGENT_DIR="${PI_DIST_DIR}/agents"
PI_ALLOWED_TOOLS_CSV="read,bash,edit,write,grep,find,ls"

enforce_rule_checks() {
  local rules_file="$1"
  local repo_root="$2"

  python3 "${REPO_ROOT}/scripts/lib/check-rules.py" \
    "${rules_file}" \
    "${repo_root}" \
    --groups-key agent_groups \
    --group-file-template 'src/agents/{item}/body.md'
}

if (( CHECK_ONLY == 1 )); then
  enforce_rule_checks "${RULES_FILE}" "${REPO_ROOT}" || exit 1
fi

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

  cp -f "${tmp_path}" "${out_path}"
  printf 'Built: %s\n' "${out_path}"
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

  mkdir -p "$(dirname -- "${out}")"
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

# Render Claude frontmatter from a meta.json into out. Field order:
# name, description, tools, then optional initialPrompt / color (unquoted).
# name falls back to the shared top-level name when the harness omits it.
render_claude_fm() {
  local meta="$1" out="$2" v
  {
    printf -- '---\n'
    printf 'name: %s\n' "$(jq -r '.harnesses.claude.name // .name' "${meta}")"
    printf 'description: %s\n' "$(jq -r '.description' "${meta}")"
    printf 'tools: %s\n' "$(jq -r '.harnesses.claude.tools' "${meta}")"
    v="$(jq -r '.harnesses.claude.initialPrompt // empty' "${meta}")"
    [[ -n "${v}" ]] && printf 'initialPrompt: %s\n' "${v}"
    v="$(jq -r '.harnesses.claude.color // empty' "${meta}")"
    [[ -n "${v}" ]] && printf 'color: %s\n' "${v}"
    printf -- '---\n\n'
  } > "${out}"
}

# Render OpenCode frontmatter from a meta.json into out. Field order:
# name, description, optional argument-hint, mode, permission block, optional
# color (quoted). name falls back to the shared top-level name.
render_opencode_fm() {
  local meta="$1" out="$2" v
  {
    printf -- '---\n'
    printf 'name: %s\n' "$(jq -r '.harnesses.opencode.name // .name' "${meta}")"
    printf 'description: %s\n' "$(jq -r '.description' "${meta}")"
    printf 'mode: %s\n' "$(jq -r '.harnesses.opencode.mode' "${meta}")"
    printf 'permission:\n'
    jq -r '.harnesses.opencode.permission | to_entries[] | "  \(.key): \(.value)"' "${meta}"
    v="$(jq -r '.harnesses.opencode.color // empty' "${meta}")"
    [[ -n "${v}" ]] && printf 'color: "%s"\n' "${v}"
    printf -- '---\n\n'
  } > "${out}"
}

# Render Copilot frontmatter from a meta.json into out. Field order:
# optional name, description, tools.
# target is intentionally omitted when unset so the profile stays compatible
# across supported Copilot environments by default.
render_copilot_fm() {
  local meta="$1" out="$2" v
  {
    printf -- '---\n'
    v="$(jq -r '.harnesses.copilot.name // empty' "${meta}")"
    [[ -n "${v}" ]] && printf 'name: %s\n' "${v}"
    printf 'description: %s\n' "$(jq -r '.description' "${meta}")"
    v="$(jq -r '.harnesses.copilot."argument-hint" // empty' "${meta}")"
    [[ -n "${v}" ]] && printf 'argument-hint: %s\n' "${v}"
    printf 'tools: %s\n' "$(jq -r '.harnesses.copilot.tools' "${meta}")"
    printf -- '---\n\n'
  } > "${out}"
}

# Render Pi frontmatter from a meta.json into out. Pi uses tools visibility
# plus optional permission policy overrides.
render_pi_fm() {
  local meta="$1" out="$2" v
  {
    printf -- '---\n'
    printf 'name: %s\n' "$(jq -r '.harnesses.pi.name // .name' "${meta}")"
    v="$(jq -r '.harnesses.pi.package // empty' "${meta}")"
    [[ -n "${v}" ]] && printf 'package: %s\n' "${v}"
    printf 'description: %s\n' "$(jq -r '.description' "${meta}")"
    printf 'tools: %s\n' "$(jq -r '.harnesses.pi.tools' "${meta}")"
    if jq -e '.harnesses.pi.permission? != null' "${meta}" >/dev/null; then
      printf 'permission:\n'
      jq -r '.harnesses.pi.permission | to_entries[] | "  \(.key): \(.value)"' "${meta}"
    fi
    printf -- '---\n\n'
  } > "${out}"
}

# Discover config agents from source-of-truth tree only.
CONFIG_AGENTS=()
if [[ -d "${SRC_AGENTS_DIR}" ]]; then
  for meta in "${SRC_AGENTS_DIR}"/*/meta.json; do
    [[ -e "${meta}" ]] || continue
    CONFIG_AGENTS+=("$(basename "$(dirname "${meta}")")")
  done
fi

for name in "${CONFIG_AGENTS[@]}"; do
  agent_dir="${SRC_AGENTS_DIR}/${name}"
  if [[ ! -f "${agent_dir}/meta.json" || ! -f "${agent_dir}/body.md" ]]; then
    printf 'ERROR: missing agent config files for %s under %s\n' "${name}" "${agent_dir}" >&2
    exit 1
  fi

  if ! jq -e '.harnesses.pi? != null' "${agent_dir}/meta.json" >/dev/null; then
    printf 'ERROR: missing required harnesses.pi config for %s in %s\n' "${name}" "${agent_dir}/meta.json" >&2
    exit 1
  fi

  if ! jq -e '.harnesses.pi.tools? != null' "${agent_dir}/meta.json" >/dev/null; then
    printf 'ERROR: missing required harnesses.pi.tools config for %s in %s\n' "${name}" "${agent_dir}/meta.json" >&2
    exit 1
  fi

  if ! jq -e --arg allowed "${PI_ALLOWED_TOOLS_CSV}" '
    (.harnesses.pi.tools // "")
    | split(",")
    | map(gsub("^\\s+|\\s+$"; ""))
    | map(select(length > 0)) as $tools
    | ($allowed | split(",")) as $allowedTools
    | ($tools | all(. as $t | $allowedTools | index($t) != null))
  ' "${agent_dir}/meta.json" >/dev/null; then
    printf 'ERROR: invalid harnesses.pi.tools for %s in %s (allowed: %s)\n' "${name}" "${agent_dir}/meta.json" "${PI_ALLOWED_TOOLS_CSV}" >&2
    exit 1
  fi
done

if (( ${#CONFIG_AGENTS[@]} == 0 )); then
  printf 'ERROR: no agent configs found under %s\n' "${SRC_AGENTS_DIR}" >&2
  exit 1
fi

mkdir -p "${CLAUDE_AGENT_DIR}"
mkdir -p "${OPENCODE_AGENT_DIR}"
mkdir -p "${COPILOT_AGENT_DIR}"
mkdir -p "${PI_AGENT_DIR}"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

# Claude entrypoint file references the shared policy.
CLAUDE_MD_TMP="${TMP_DIR}/CLAUDE.md"
cat > "${CLAUDE_MD_TMP}" <<'EOF'
@AGENTS.md
EOF
render_or_check_file "${CLAUDE_MD_TMP}" "${CLAUDE_MD_OUT}"

# Render each agent for every harness: harness frontmatter + shared body.
for name in "${CONFIG_AGENTS[@]}"; do
  agent_dir="${SRC_AGENTS_DIR}/${name}"
  meta="${agent_dir}/meta.json"
  body="${agent_dir}/body.md"
  rendered_body="${TMP_DIR}/body-${name}.md"

  render_body_markdown "${body}" "${rendered_body}"

  claude_tmp="${TMP_DIR}/claude-${name}.md"
  render_claude_fm "${meta}" "${claude_tmp}"
  cat "${rendered_body}" >> "${claude_tmp}"
  render_or_check_file "${claude_tmp}" "${CLAUDE_AGENT_DIR}/${name}.md"

  opencode_tmp="${TMP_DIR}/opencode-${name}.md"
  render_opencode_fm "${meta}" "${opencode_tmp}"
  cat "${rendered_body}" >> "${opencode_tmp}"
  render_or_check_file "${opencode_tmp}" "${OPENCODE_AGENT_DIR}/${name}.md"

  pi_tmp="${TMP_DIR}/pi-${name}.md"
  render_pi_fm "${meta}" "${pi_tmp}"
  cat "${rendered_body}" >> "${pi_tmp}"
  render_or_check_file "${pi_tmp}" "${PI_AGENT_DIR}/${name}.md"

  # Copilot rendering is opt-in per agent until all meta.json files include
  # a harnesses.copilot section.
  if jq -e '.harnesses.copilot? != null' "${meta}" >/dev/null; then
    copilot_tmp="${TMP_DIR}/copilot-${name}.md"
    render_copilot_fm "${meta}" "${copilot_tmp}"
    cat "${rendered_body}" >> "${copilot_tmp}"
    render_or_check_file "${copilot_tmp}" "${COPILOT_AGENT_DIR}/${name}.md"
  fi
done
