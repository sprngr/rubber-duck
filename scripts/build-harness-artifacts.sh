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

ROUTER_BODY="${REPO_ROOT}/agents/src/rubber-duck.body.md"
ROOT_AGENTS_MD="${REPO_ROOT}/AGENTS.md"
ROOT_AGENTS_DIR="${REPO_ROOT}/agents"

CLAUDE_DIST_DIR="${REPO_ROOT}/dist/claude"
CLAUDE_AGENT_DIR="${CLAUDE_DIST_DIR}/agents"
CLAUDE_ROUTER_OUT="${CLAUDE_AGENT_DIR}/rubber-duck.md"
CLAUDE_MD_OUT="${CLAUDE_DIST_DIR}/CLAUDE.md"

OPENCODE_DIST_DIR="${REPO_ROOT}/dist/opencode"
OPENCODE_AGENT_DIR="${OPENCODE_DIST_DIR}/agents"
OPENCODE_AGENTS_MD_OUT="${OPENCODE_DIST_DIR}/AGENTS.md"

OPENCODE_AGENT_FILES=(
  "rubber-duck.agent.md"
  "duck-simple.agent.md"
  "duck-reviewer.agent.md"
  "duck-investigator.agent.md"
  "duck-dry.agent.md"
  "duck-builder.agent.md"
  "duck-adversary.agent.md"
)

CLAUDE_SUBAGENT_SPECS=(
  "duck-simple.agent.md|duck-simple|Use for simplicity review to reduce overengineering, indirection, and unnecessary abstractions.|Read, Glob, Grep, Skill"
  "duck-reviewer.agent.md|duck-reviewer|Use for focused diff/file review with severity-tagged findings and concrete fixes.|Read, Glob, Grep, Bash, Skill"
  "duck-investigator.agent.md|duck-investigator|Use for read-only code location, reference mapping, and call-chain tracing before debug/review/design.|Read, Glob, Grep, Skill"
  "duck-dry.agent.md|duck-dry|Use for DRY review to find meaningful duplication and divergence risk with safe extraction boundaries.|Read, Glob, Grep, Skill"
  "duck-builder.agent.md|duck-builder|Use for surgical implementation edits (1-2 files) after duck diagnosis/review confirms bounded scope.|Read, Glob, Grep, Edit, Bash, Skill"
  "duck-adversary.agent.md|duck-adversary|Use for adversarial review of risks, failure modes, compatibility, and rollback safety.|Read, Glob, Grep, Skill"
)

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

append_body_without_frontmatter() {
  local src="$1"
  local out="$2"
  awk '
    NR == 1 && $0 == "---" { in_fm=1; next }
    in_fm == 1 && $0 == "---" { in_fm=0; next }
    in_fm == 1 { next }
    { print }
  ' "${src}" >> "${out}"
}

if [[ ! -f "${ROUTER_BODY}" ]]; then
  printf 'ERROR: missing canonical router body: %s\n' "${ROUTER_BODY}" >&2
  exit 1
fi

if [[ ! -f "${ROOT_AGENTS_MD}" ]]; then
  printf 'ERROR: missing AGENTS policy source: %s\n' "${ROOT_AGENTS_MD}" >&2
  exit 1
fi

for f in "${OPENCODE_AGENT_FILES[@]}"; do
  if [[ ! -f "${ROOT_AGENTS_DIR}/${f}" ]]; then
    printf 'ERROR: missing OpenCode agent source: %s\n' "${ROOT_AGENTS_DIR}/${f}" >&2
    exit 1
  fi
done

mkdir -p "${CLAUDE_AGENT_DIR}"
mkdir -p "${OPENCODE_AGENT_DIR}"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

CLAUDE_ROUTER_TMP="${TMP_DIR}/rubber-duck.md"
cat > "${CLAUDE_ROUTER_TMP}" <<'EOF'
---
name: rubber-duck
description: Rubber duck for code review, debugging, design, and testing.
tools: Read, Glob, Grep, Edit, Write, Bash, Agent, Skill, AskUserQuestion
initalPrompt: true
color: yellow
---

EOF

cat "${ROUTER_BODY}" >> "${CLAUDE_ROUTER_TMP}"
render_file "${CLAUDE_ROUTER_OUT}" "${CLAUDE_ROUTER_TMP}"

CLAUDE_MD_TMP="${TMP_DIR}/CLAUDE.md"
cat > "${CLAUDE_MD_TMP}" <<'EOF'
@AGENTS.md
EOF
render_file "${CLAUDE_MD_OUT}" "${CLAUDE_MD_TMP}"

for spec in "${CLAUDE_SUBAGENT_SPECS[@]}"; do
  IFS='|' read -r src_file agent_name agent_desc agent_tools <<< "${spec}"
  src_path="${ROOT_AGENTS_DIR}/${src_file}"
  out_path="${CLAUDE_AGENT_DIR}/${agent_name}.md"
  tmp_path="${TMP_DIR}/claude-${agent_name}.md"

  cat > "${tmp_path}" <<EOF
---
name: ${agent_name}
description: ${agent_desc}
tools: ${agent_tools}
---

EOF
  append_body_without_frontmatter "${src_path}" "${tmp_path}"
  render_file "${out_path}" "${tmp_path}"
done

OPENCODE_AGENTS_MD_TMP="${TMP_DIR}/opencode-AGENTS.md"
cat > "${OPENCODE_AGENTS_MD_TMP}" <<EOF
EOF
cat "${ROOT_AGENTS_MD}" >> "${OPENCODE_AGENTS_MD_TMP}"
render_file "${OPENCODE_AGENTS_MD_OUT}" "${OPENCODE_AGENTS_MD_TMP}"

for f in "${OPENCODE_AGENT_FILES[@]}"; do
  opencode_tmp="${TMP_DIR}/opencode-${f}"
  cat > "${opencode_tmp}" <<EOF
EOF
  cat "${ROOT_AGENTS_DIR}/${f}" >> "${opencode_tmp}"
  render_file "${OPENCODE_AGENT_DIR}/${f}" "${opencode_tmp}"
done
