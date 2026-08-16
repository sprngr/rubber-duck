#!/usr/bin/env bash
set -euo pipefail

# Generated wrapper template source.
# Installer will substitute scope token and source URL token.

SYNC_INSTALLER_URL="{{SYNC_INSTALLER_URL}}"
SYNC_SCOPE_FLAG="{{SYNC_SCOPE_FLAG}}"

if [[ "${SYNC_INSTALLER_URL}" == https://* || "${SYNC_INSTALLER_URL}" == http://* ]]; then
  tmp_installer="$(mktemp)"
  cleanup() { rm -f "${tmp_installer}"; }
  trap cleanup EXIT
  curl -fsSL "${SYNC_INSTALLER_URL}" -o "${tmp_installer}"
  bash "${tmp_installer}" sync "${SYNC_SCOPE_FLAG}" --source web "$@"
else
  bash "${SYNC_INSTALLER_URL}" sync "${SYNC_SCOPE_FLAG}" --source local "$@"
fi
