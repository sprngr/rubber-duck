#!/usr/bin/env bash
set -euo pipefail

BASE_REF="${1:-HEAD~1}"

if ! git rev-parse --verify "$BASE_REF" >/dev/null 2>&1; then
  echo "[governance-guard] skip: base ref '$BASE_REF' not found"
  exit 0
fi

CHANGED_FILES="$(git diff --name-only "$BASE_REF"..HEAD)"

if [[ -z "$CHANGED_FILES" ]]; then
  echo "[governance-guard] no changes detected"
  exit 0
fi

AGENT_OR_SKILL_CHANGED=false
RUN_FILE_ADDED=false

while IFS= read -r file; do
  [[ -z "$file" ]] && continue

  if [[ "$file" == agents/* ]] || [[ "$file" == skills/* ]]; then
    AGENT_OR_SKILL_CHANGED=true
  fi

  if [[ "$file" == docs/governance/runs/* ]]; then
    RUN_FILE_ADDED=true
  fi
done <<< "$CHANGED_FILES"

if [[ "$AGENT_OR_SKILL_CHANGED" == true ]] && [[ "$RUN_FILE_ADDED" == false ]]; then
  echo "[governance-guard] fail: agents/skills changed but no file changed under docs/governance/runs/"
  echo "[governance-guard] fix: add rubric/behavior run evidence file under docs/governance/runs/"
  exit 1
fi

echo "[governance-guard] ok"
