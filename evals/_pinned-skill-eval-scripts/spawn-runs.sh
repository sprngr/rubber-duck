#!/usr/bin/env bash
# spawn-runs.sh - Generate subagent dispatch instructions for eval runs
# Usage: spawn-runs.sh <workspace-dir> <iteration> <evals-json> <skill-snapshot-path>
# Outputs dispatch instructions to stdout for each eval (with and without skill).

set -euo pipefail

WORKSPACE="${1:?Usage: $0 <workspace-dir> <iteration> <evals-json> <skill-snapshot-path>}"
ITERATION="${2:?Usage: $0 <workspace-dir> <iteration> <evals-json> <skill-snapshot-path>}"
EVALS_JSON="${3:?Usage: $0 <workspace-dir> <iteration> <evals-json> <skill-snapshot-path>}"
SKILL_SNAPSHOT="${4:?Usage: $0 <workspace-dir> <iteration> <evals-json> <skill-snapshot-path>}"

python3 "$(dirname "$0")/spawn_runs.py" "$WORKSPACE/$ITERATION" "$EVALS_JSON" "$SKILL_SNAPSHOT"
