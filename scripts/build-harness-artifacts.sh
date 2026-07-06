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
RULES_FILE="${REPO_ROOT}/build/agent-assembly/rules.json"

SRC_AGENTS_DIR="${REPO_ROOT}/src/agents"
POLICY_SNIPPETS_DIR="${REPO_ROOT}/src/shared/policy-snippets"

CLAUDE_DIST_DIR="${REPO_ROOT}/dist/claude"
CLAUDE_AGENT_DIR="${CLAUDE_DIST_DIR}/agents"
CLAUDE_MD_OUT="${CLAUDE_DIST_DIR}/CLAUDE.md"

OPENCODE_DIST_DIR="${REPO_ROOT}/dist/opencode"
OPENCODE_AGENT_DIR="${OPENCODE_DIST_DIR}/agents"

COPILOT_DIST_DIR="${REPO_ROOT}/dist/copilot"
COPILOT_AGENT_DIR="${COPILOT_DIST_DIR}/agents"

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

if (( CHECK_ONLY == 1 )); then
  enforce_rule_checks "${RULES_FILE}" "${REPO_ROOT}" || exit 1
fi

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

render_body_markdown() {
  local src="$1"
  local out="$2"
  local line=""

  if [[ ! -f "${src}" ]]; then
    printf 'ERROR: missing body source file: %s\n' "${src}" >&2
    return 1
  fi

  mkdir -p "$(dirname -- "${out}")"
  : > "${out}"

  while IFS= read -r line || [[ -n "${line}" ]]; do
    if [[ "${line}" =~ ^[[:space:]]*\{\{include:[[:space:]]*policy-snippets/([^[:space:]\}]+)[[:space:]]*\}\}[[:space:]]*$ ]]; then
      local snippet_name="${BASH_REMATCH[1]}"
      local snippet_path="${POLICY_SNIPPETS_DIR}/${snippet_name}"
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
done

if (( ${#CONFIG_AGENTS[@]} == 0 )); then
  printf 'ERROR: no agent configs found under %s\n' "${SRC_AGENTS_DIR}" >&2
  exit 1
fi

mkdir -p "${CLAUDE_AGENT_DIR}"
mkdir -p "${OPENCODE_AGENT_DIR}"
mkdir -p "${COPILOT_AGENT_DIR}"

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
  agent_dir="${SRC_AGENTS_DIR}/${name}"
  meta="${agent_dir}/meta.json"
  body="${agent_dir}/body.md"
  rendered_body="${TMP_DIR}/body-${name}.md"

  render_body_markdown "${body}" "${rendered_body}"

  claude_tmp="${TMP_DIR}/claude-${name}.md"
  render_claude_fm "${meta}" "${claude_tmp}"
  cat "${rendered_body}" >> "${claude_tmp}"
  render_file "${CLAUDE_AGENT_DIR}/${name}.md" "${claude_tmp}"

  opencode_tmp="${TMP_DIR}/opencode-${name}.md"
  render_opencode_fm "${meta}" "${opencode_tmp}"
  cat "${rendered_body}" >> "${opencode_tmp}"
  render_file "${OPENCODE_AGENT_DIR}/${name}.md" "${opencode_tmp}"

  # Copilot rendering is opt-in per agent until all meta.json files include
  # a harnesses.copilot section.
  if jq -e '.harnesses.copilot? != null' "${meta}" >/dev/null; then
    copilot_tmp="${TMP_DIR}/copilot-${name}.md"
    render_copilot_fm "${meta}" "${copilot_tmp}"
    cat "${rendered_body}" >> "${copilot_tmp}"
    render_file "${COPILOT_AGENT_DIR}/${name}.md" "${copilot_tmp}"
  fi
done
