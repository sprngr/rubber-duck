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

ROOT_AGENTS_DIR="${REPO_ROOT}/agents"

CLAUDE_DIST_DIR="${REPO_ROOT}/dist/claude"
CLAUDE_AGENT_DIR="${CLAUDE_DIST_DIR}/agents"
CLAUDE_MD_OUT="${CLAUDE_DIST_DIR}/CLAUDE.md"

OPENCODE_DIST_DIR="${REPO_ROOT}/dist/opencode"
OPENCODE_AGENT_DIR="${OPENCODE_DIST_DIR}/agents"

render_file() {
  local out_path="$1"
  local tmp_path="$2"

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
    v="$(jq -r '.harnesses.opencode."argument-hint" // empty' "${meta}")"
    [[ -n "${v}" ]] && printf 'argument-hint: %s\n' "${v}"
    printf 'mode: %s\n' "$(jq -r '.harnesses.opencode.mode' "${meta}")"
    printf 'permission:\n'
    jq -r '.harnesses.opencode.permission | to_entries[] | "  \(.key): \(.value)"' "${meta}"
    v="$(jq -r '.harnesses.opencode.color // empty' "${meta}")"
    [[ -n "${v}" ]] && printf 'color: "%s"\n' "${v}"
    printf -- '---\n'
  } > "${out}"
}

# Discover config agents: any agents/<name>/ containing a meta.json.
CONFIG_AGENTS=()
for meta in "${ROOT_AGENTS_DIR}"/*/meta.json; do
  [[ -e "${meta}" ]] || continue
  CONFIG_AGENTS+=("$(basename "$(dirname "${meta}")")")
done
if (( ${#CONFIG_AGENTS[@]} == 0 )); then
  printf 'ERROR: no agent configs found under %s\n' "${ROOT_AGENTS_DIR}" >&2
  exit 1
fi

for name in "${CONFIG_AGENTS[@]}"; do
  if [[ ! -f "${ROOT_AGENTS_DIR}/${name}/body.md" ]]; then
    printf 'ERROR: missing agent body: %s\n' "${ROOT_AGENTS_DIR}/${name}/body.md" >&2
    exit 1
  fi
done

mkdir -p "${CLAUDE_AGENT_DIR}"
mkdir -p "${OPENCODE_AGENT_DIR}"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

# Claude entrypoint file references the shared policy.
CLAUDE_MD_TMP="${TMP_DIR}/CLAUDE.md"
cat > "${CLAUDE_MD_TMP}" <<'EOF'
@AGENTS.md
EOF
render_file "${CLAUDE_MD_OUT}" "${CLAUDE_MD_TMP}"

# Render each agent for every harness: harness frontmatter + shared body.
for name in "${CONFIG_AGENTS[@]}"; do
  meta="${ROOT_AGENTS_DIR}/${name}/meta.json"
  body="${ROOT_AGENTS_DIR}/${name}/body.md"

  claude_tmp="${TMP_DIR}/claude-${name}.md"
  render_claude_fm "${meta}" "${claude_tmp}"
  cat "${body}" >> "${claude_tmp}"
  render_file "${CLAUDE_AGENT_DIR}/${name}.md" "${claude_tmp}"

  opencode_tmp="${TMP_DIR}/opencode-${name}.md"
  render_opencode_fm "${meta}" "${opencode_tmp}"
  cat "${body}" >> "${opencode_tmp}"
  render_file "${OPENCODE_AGENT_DIR}/${name}.md" "${opencode_tmp}"
done
