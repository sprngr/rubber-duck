#!/usr/bin/env bash
# scaffold-workspace.sh - Create eval workspace tree for an iteration
# Requires: jq, python3
# Usage: scaffold-workspace.sh <workspace-dir> <iteration-name> <evals-json-path>
# Example: scaffold-workspace.sh my-skill-evals iteration-1 my-skill/evals/evals.json

set -euo pipefail

WORKSPACE="${1:?Usage: $0 <workspace-dir> <iteration-name> <evals-json-path>}"
ITERATION="${2:?Usage: $0 <workspace-dir> <iteration-name> <evals-json-path>}"
EVALS_JSON="${3:?Usage: $0 <workspace-dir> <iteration-name> <evals-json-path>}"

if [ ! -f "$EVALS_JSON" ]; then
  echo "ERROR: evals.json not found at $EVALS_JSON" >&2
  exit 1
fi

mkdir -p "$WORKSPACE/$ITERATION"

# Parse eval IDs and slugs from evals.json using jq (or python fallback)
parse_evals() {
  if command -v jq &>/dev/null; then
    jq -r '.evals[] | @base64' "$EVALS_JSON" | while read -r encoded; do
      id=$(echo "$encoded" | base64 -d | jq -r '.id')
      prompt=$(echo "$encoded" | base64 -d | jq -r '.prompt')
      # Create slug from first few words of prompt
      slug=$(echo "$prompt" | tr '[:upper:]' '[:lower:]' | tr -cs '[:alnum:]' '-' | head -c 40)
      echo "eval-${slug}-${id}"
    done
  else
    python3 -c "
import json, hashlib, sys
with open('$EVALS_JSON') as f:
    data = json.load(f)
for e in data['evals']:
    slug = e['prompt'][:40].lower().replace(' ', '-')
    print(f'eval-{slug}-{e[\"id\"]}')
"
  fi
}

for slug in $(parse_evals); do
  dir="$WORKSPACE/$ITERATION/$slug"
  mkdir -p "$dir/with_skill/outputs"
  mkdir -p "$dir/without_skill/outputs"
  echo "  ✅ $slug/"
done

echo "Scaffolded $ITERATION in $WORKSPACE"
echo "Eval count: $(parse_evals | wc -l)"
