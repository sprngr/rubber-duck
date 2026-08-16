$ErrorActionPreference = "Stop"

# RUBBER_DUCK_VERSION: v2.2.0
# Generated wrapper template source.
# Installer will substitute scope token and source URL token.

$SyncInstallerUrl = "{{SYNC_INSTALLER_URL}}"
$SyncScopeArg = "{{SYNC_SCOPE_ARG}}"
$InstallerHash = "66c6ef5e823fb85b338d7956d50c4c0e2cfe9ceceed90dcf064c8ec0dcf0688a"

$isRemote = $SyncInstallerUrl -match '^https?://'

# Detect current PowerShell host for re-invocation
$psHost = $PSVersionInfo.PSExecutable
if ([string]::IsNullOrWhiteSpace($psHost)) {
  $psHost = "pwsh"
  try { Get-Command pwsh -ErrorAction Stop | Out-Null } catch {
    $psHost = "powershell"
  }
}

# --- Version check ---
$currentVersion = ""
$manifest = if ($SyncScopeArg -eq "--project") { ".rubber-duck/manifest.json" } else { Join-Path $HOME ".config/rubber-duck/manifest.json" }
if (Test-Path $manifest) {
  try {
    $m = Get-Content -Raw $manifest | ConvertFrom-Json
    if ($m.source -and $m.source.lastAppliedVersion) { $currentVersion = [string]$m.source.lastAppliedVersion }
  } catch { }
}
$remoteVersion = ""
if ($isRemote) {
  try {
    $remoteVersion = (Invoke-WebRequest -UseBasicParsing -Uri "https://raw.githubusercontent.com/sprngr/rubber-duck/main/VERSION" -ErrorAction Stop).Content.Trim()
  } catch { }
} else {
  $localVersionFile = Join-Path (Split-Path -Parent (Split-Path -Parent $SyncInstallerUrl)) "VERSION"
  if (Test-Path $localVersionFile) {
    try { $remoteVersion = (Get-Content -Raw $localVersionFile).Trim() } catch { }
  }
}
if (-not [string]::IsNullOrWhiteSpace($currentVersion) -and -not [string]::IsNullOrWhiteSpace($remoteVersion)) {
  if ($currentVersion -eq $remoteVersion) {
    Write-Host "Already up to date ($currentVersion)."
  } else {
    $curVer = $null
    $remVer = $null
    try { $curVer = [version]($currentVersion.TrimStart('v')) } catch { }
    try { $remVer = [version]($remoteVersion.TrimStart('v')) } catch { }
    if ($null -ne $curVer -and $null -ne $remVer -and $curVer -lt $remVer) {
      Write-Host "New version available: $currentVersion -> $remoteVersion"
      Write-Host "Changelog: https://github.com/sprngr/rubber-duck/blob/main/CHANGELOG.md"
      $reply = Read-Host "Update now? [y/N]"
      if ($reply -ne "y" -and $reply -ne "Y") { Write-Host "Skipping update."; exit 0 }
    } elseif ($null -ne $curVer -and $null -ne $remVer) {
      Write-Host "WARNING: local version ($currentVersion) is newer than remote ($remoteVersion)."
    } else {
      Write-Host "Unable to compare versions: $currentVersion vs $remoteVersion. Syncing anyway."
    }
  }
}

if ($isRemote) {
  $tmpRoot = if ([string]::IsNullOrWhiteSpace($env:TEMP)) { [System.IO.Path]::GetTempPath() } else { $env:TEMP }
  $tmp = Join-Path $tmpRoot ("rubber-duck-sync-" + [Guid]::NewGuid().ToString() + ".ps1")
  try {
    Invoke-WebRequest -UseBasicParsing -Uri $SyncInstallerUrl -OutFile $tmp
    if (-not [string]::IsNullOrWhiteSpace($InstallerHash)) {
      $actualHash = (Get-FileHash -Algorithm SHA256 -Path $tmp).Hash.ToLower()
      if ($actualHash -ne $InstallerHash.ToLower()) {
        throw "Installer hash mismatch (expected $InstallerHash, got $actualHash). The installer may have been tampered with."
      }
    }
    & $psHost -NoProfile -File $tmp -Action sync $SyncScopeArg -Source web @args
    exit $LASTEXITCODE
  } finally {
    if (Test-Path $tmp) { Remove-Item -Force $tmp }
  }
} else {
  & $psHost -NoProfile -File $SyncInstallerUrl -Action sync $SyncScopeArg -Source local @args
  exit $LASTEXITCODE
}
