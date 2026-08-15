$ErrorActionPreference = "Stop"

# Generated wrapper template source.
# Installer will substitute scope token and source URL token.

$SyncInstallerUrl = "{{SYNC_INSTALLER_URL}}"
$SyncScopeArg = "{{SYNC_SCOPE_ARG}}"

if ($SyncInstallerUrl -match '^https?://') {
  $tmpRoot = if ([string]::IsNullOrWhiteSpace($env:TEMP)) { [System.IO.Path]::GetTempPath() } else { $env:TEMP }
  $tmp = Join-Path $tmpRoot ("rubber-duck-sync-" + [Guid]::NewGuid().ToString() + ".ps1")
  try {
    Invoke-WebRequest -UseBasicParsing -Uri $SyncInstallerUrl -OutFile $tmp
    & pwsh -NoProfile -File $tmp -Action sync $SyncScopeArg -Source web @args
    exit $LASTEXITCODE
  } finally {
    if (Test-Path $tmp) { Remove-Item -Force $tmp }
  }
} else {
  & pwsh -NoProfile -File $SyncInstallerUrl -Action sync $SyncScopeArg -Source local @args
  exit $LASTEXITCODE
}
