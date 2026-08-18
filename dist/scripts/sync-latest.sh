#!/usr/bin/env bash
set -euo pipefail

# RUBBER_DUCK_VERSION: v3.0.0
# Generated wrapper template source.
# Installer will substitute scope token and source URL token.

SYNC_INSTALLER_URL="{{SYNC_INSTALLER_URL}}"
SYNC_SCOPE_FLAG="{{SYNC_SCOPE_FLAG}}"

IS_REMOTE=0
[[ "${SYNC_INSTALLER_URL}" == https://* || "${SYNC_INSTALLER_URL}" == http://* ]] && IS_REMOTE=1

# --- Version check ---
CURRENT_VERSION=""
if [[ "${SYNC_SCOPE_FLAG}" == "--project" ]]; then
  MANIFEST=".rubber-duck/manifest.json"
else
  MANIFEST="${HOME}/.config/rubber-duck/manifest.json"
fi
if [[ -f "${MANIFEST}" ]]; then
  CURRENT_VERSION=$(sed -n 's/.*"lastAppliedVersion":[[:space:]]*"\([^"]*\)".*/\1/p' "${MANIFEST}" 2>/dev/null | tr -d '[:space:]' || true)
fi
REMOTE_BASE="${SYNC_INSTALLER_URL%/*/*}"
REMOTE_VERSION=""
if (( IS_REMOTE )); then
  REMOTE_VERSION_URL="${REMOTE_BASE}/VERSION"
  REMOTE_VERSION=$(curl -fsSL "${REMOTE_VERSION_URL}" 2>/dev/null | tr -d '\r\n[:space:]' || true)
else
  LOCAL_VERSION_FILE="$(cd -- "$(dirname -- "${SYNC_INSTALLER_URL}")/.." && pwd)/VERSION"
  [[ -f "${LOCAL_VERSION_FILE}" ]] && REMOTE_VERSION=$(tr -d '\r\n[:space:]' < "${LOCAL_VERSION_FILE}" 2>/dev/null || true)
fi
if [[ -n "${CURRENT_VERSION}" && -n "${REMOTE_VERSION}" ]]; then
  if [[ "${CURRENT_VERSION}" == "${REMOTE_VERSION}" ]]; then
    echo "Already up to date (${CURRENT_VERSION})."
  elif [[ "$(printf '%s\n%s\n' "${CURRENT_VERSION}" "${REMOTE_VERSION}" | sort -V | tail -n1)" == "${REMOTE_VERSION}" ]]; then
    echo "New version available: ${CURRENT_VERSION} -> ${REMOTE_VERSION}"
    echo "Changelog: https://github.com/sprngr/rubber-duck/blob/main/CHANGELOG.md"
    printf "Update now? [y/N] "
    read -r REPLY
    if [[ "${REPLY}" != "y" && "${REPLY}" != "Y" ]]; then
      echo "Skipping update."
      exit 0
    fi
  else
    echo "WARNING: local version (${CURRENT_VERSION}) is newer than remote (${REMOTE_VERSION})."
  fi
fi

# Reject user-supplied scope flags: wrapper is scope-locked at install time.
for arg in "$@"; do
  case "${arg}" in
    --project|--global)
      echo "sync-latest.sh: cannot override scope; wrapper is scoped to ${SYNC_SCOPE_FLAG}." >&2
      echo "  Re-run installer with the desired scope to change." >&2
      exit 2
      ;;
  esac
done

if (( IS_REMOTE )); then
  tmp_installer="$(mktemp)"
  cleanup() { rm -f "${tmp_installer}"; }
  trap cleanup EXIT
  curl -fsSL "${SYNC_INSTALLER_URL}" -o "${tmp_installer}"
  bash "${tmp_installer}" sync "${SYNC_SCOPE_FLAG}" --source web --raw-base "${REMOTE_BASE}" "$@"
else
  bash "${SYNC_INSTALLER_URL}" sync "${SYNC_SCOPE_FLAG}" --source local "$@"
fi
