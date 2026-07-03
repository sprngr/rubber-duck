#!/usr/bin/env bash
# aggregate-benchmark.sh - Compute benchmark stats from iteration directory
# Usage: aggregate-benchmark.sh <iteration-dir>
# Reads all grading.json and timing.json files. Writes benchmark.json.

set -euo pipefail

ITER_DIR="${1:?Usage: $0 <iteration-dir>}"

python3 "$(dirname "$0")/aggregate_benchmark.py" "$ITER_DIR"
