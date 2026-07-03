#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CANONICAL="$ROOT/skills/_shared/GUARDRAILS.md"

if [ ! -f "$CANONICAL" ]; then
  echo "Missing canonical guardrails: $CANONICAL" >&2
  exit 1
fi

for skill_dir in "$ROOT"/skills/duck-*; do
  [ -d "$skill_dir" ] || continue
  mkdir -p "$skill_dir/references"
  cp "$CANONICAL" "$skill_dir/references/GUARDRAILS.md"
done

echo "Synced guardrails to duck skill references."
