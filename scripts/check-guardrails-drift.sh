#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CANONICAL="$ROOT/src/shared/references/GUARDRAILS.md"
VERSION_FILE="$ROOT/VERSION"

if [ ! -f "$CANONICAL" ]; then
  echo "Missing canonical guardrails: $CANONICAL" >&2
  exit 1
fi
if [ ! -f "$VERSION_FILE" ]; then
  echo "Missing VERSION file: $VERSION_FILE" >&2
  exit 1
fi

VERSION_VALUE="$(tr -d '\r\n' < "$VERSION_FILE")"
if ! printf '%s' "$VERSION_VALUE" | grep -Eq '^v[0-9]+\.[0-9]+\.[0-9]+$'; then
  echo "Invalid VERSION format: $VERSION_VALUE (expected vX.Y.Z)" >&2
  exit 1
fi

failed=0

for skill_dir in "$ROOT"/skills/*; do
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

# Guard: no duplicate headings within a single rendered dist artifact.
# Covers markdown ATX headings (#, ##, ###, ...) and bold-emphasis pseudo-headers
# (**...** / **...:**). Catches nested-include composition bugs where the same
# snippet is included more than once (adjacent or not).
while IFS= read -r -d '' dist_file; do
  if ! awk '
    /^#+[[:space:]]+.+[[:space:]]*$/ || /^\*\*.+\*\*:?[[:space:]]*$/ {
      if ($0 in seen) {
        print FILENAME ":" NR ": duplicate heading (first at line " seen[$0] "): " $0 > "/dev/stderr"
        found=1
      } else { seen[$0] = NR }
    }
    END { if (found) exit 1 }
  ' "$dist_file"; then
    failed=1
  fi
done < <(find "$ROOT/dist" -type f -name '*.md' -print0)

if [ "$failed" -ne 0 ]; then
  echo "Guardrails drift check failed." >&2
  exit 1
fi

echo "Guardrails drift check passed."
