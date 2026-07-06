#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CANONICAL="$ROOT/src/skills/shared/references/GUARDRAILS.md"

if [ ! -f "$CANONICAL" ]; then
  echo "Missing canonical guardrails: $CANONICAL" >&2
  exit 1
fi

failed=0

for skill_dir in "$ROOT"/skills/duck-*; do
  [ -d "$skill_dir" ] || continue
  vendored="$skill_dir/references/GUARDRAILS.md"
  if [ ! -f "$vendored" ]; then
    echo "Missing vendored guardrails: $vendored" >&2
    failed=1
    continue
  fi
  if ! cmp -s "$CANONICAL" "$vendored"; then
    echo "Drift detected: $vendored differs from canonical" >&2
    failed=1
  fi
done

if [ "$failed" -ne 0 ]; then
  echo "Guardrails drift check failed." >&2
  exit 1
fi

echo "Guardrails drift check passed."
