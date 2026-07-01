#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${0}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

"${REPO_ROOT}/scripts/build-harness-artifacts.sh" --check

printf 'Harness artifacts are up to date.\n'
