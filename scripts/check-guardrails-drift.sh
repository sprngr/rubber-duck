#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CANONICAL="$ROOT/src/shared/references/GUARDRAILS.md"
REPO_AGENTS="$ROOT/AGENTS.md"
DIST_AGENTS="$ROOT/dist/AGENTS.md"
VERSION_FILE="$ROOT/VERSION"
MANAGED_START="<!-- RUBBER_DUCK_MANAGED_BLOCK START -->"
MANAGED_END="<!-- RUBBER_DUCK_MANAGED_BLOCK END -->"

if [ ! -f "$CANONICAL" ]; then
  echo "Missing canonical guardrails: $CANONICAL" >&2
  exit 1
fi
if [ ! -f "$REPO_AGENTS" ]; then
  echo "Missing repository AGENTS file: $REPO_AGENTS" >&2
  exit 1
fi
if [ ! -f "$DIST_AGENTS" ]; then
  echo "Missing dist AGENTS file: $DIST_AGENTS" >&2
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

managed_tmp="$(mktemp)"
cleanup() { rm -f "$managed_tmp"; }
trap cleanup EXIT

if ! awk -v start="$MANAGED_START" -v end="$MANAGED_END" '
  $0 == start { in_block=1; seen_start=1; next }
  $0 == end   { in_block=0; seen_end=1; next }
  in_block { print }
  END {
    if (!seen_start || !seen_end) exit 2
  }
' "$REPO_AGENTS" > "$managed_tmp"; then
  echo "Managed policy block missing or malformed in: $REPO_AGENTS" >&2
  failed=1
elif ! cmp -s "$managed_tmp" "$DIST_AGENTS"; then
  echo "Drift detected: managed block in AGENTS.md differs from dist/AGENTS.md" >&2
  failed=1
fi

if ! grep -Fq "RUBBER_DUCK_VERSION: ${VERSION_VALUE}" "$DIST_AGENTS"; then
  echo "Drift detected: dist/AGENTS.md version marker does not match VERSION (${VERSION_VALUE})" >&2
  failed=1
fi

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
