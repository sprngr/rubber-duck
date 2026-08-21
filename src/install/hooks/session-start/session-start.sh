#!/usr/bin/env bash
# session-start hook for Claude Code (unix)
# Reads SessionStart JSON from stdin; if agent_type == "rubber-duck", emits
# hookSpecificOutput.additionalContext with the shared directive. No-op otherwise.
set -euo pipefail

DIRECTIVE_CANDIDATES=(
  "${CLAUDE_PROJECT_DIR:-.}/.opencode/session-start.directive.md"
  "${CLAUDE_PROJECT_DIR:-.}/.agents/session-start.directive.md"
)

# Read stdin once
stdin_json="$(cat 2>/dev/null || true)"
if [[ -z "$stdin_json" ]]; then
  exit 0
fi

# Extract agent_type. Missing or not rubber-duck => silent no-op.
agent_type="$(printf '%s' "$stdin_json" | jq -r '.agent_type // empty' 2>/dev/null || true)"
if [[ "$agent_type" != "rubber-duck" ]]; then
  exit 0
fi

# Locate and read directive
directive=""
for p in "${DIRECTIVE_CANDIDATES[@]}"; do
  if [[ -f "$p" ]]; then
    directive="$(cat "$p")"
    break
  fi
done
if [[ -z "$directive" ]]; then
  exit 0
fi

# Emit additionalContext (jq handles JSON escaping)
jq -n --arg ctx "$directive" \
  '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $ctx}}'
