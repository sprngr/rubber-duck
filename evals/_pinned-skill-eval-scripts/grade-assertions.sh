#!/usr/bin/env bash
# grade-assertions.sh - Deterministic assertion grading via Python
# Usage: grade-assertions.sh <output-dir> <assertions-json-file>
# Reads assertions from JSON file. Outputs partial grading JSON to stdout.

set -euo pipefail

OUTPUT_DIR="${1:?Usage: $0 <output-dir> <assertions-json-file>}"
ASSERTIONS_FILE="${2:?Usage: $0 <output-dir> <assertions-json-file>}"

python3 "$(dirname "$0")/grade_assertions.py" "$OUTPUT_DIR" "$ASSERTIONS_FILE"
