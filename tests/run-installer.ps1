#!/usr/bin/env pwsh
# Installer behavioral tests: fresh install, reinstall, sync, prune, allowlist, dry-run.
# Runs the real PowerShell installer against local dist/, in isolated tmp workspaces.
# Parity with tests/run-installer.sh (bash suite).
$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot  = Resolve-Path (Join-Path $scriptDir "..")
$script:PsInstaller = Join-Path $repoRoot "scripts/rubber-duck.ps1"

$script:Failures = 0
$script:TestsRun = 0

function Setup-Workspace {
  $ws = Join-Path ([System.IO.Path]::GetTempPath()) ("rd-installer-test-" + [System.Guid]::NewGuid().ToString("N").Substring(0,10))
  New-Item -ItemType Directory -Path $ws | Out-Null
  return $ws
}

function Teardown-Workspace([string]$Ws) {
  if ($Ws -and (Test-Path $Ws) -and $Ws.StartsWith([System.IO.Path]::GetTempPath())) {
    Remove-Item -Recurse -Force $Ws
  }
}

function Run-Test([string]$Name, [scriptblock]$Fn) {
  $script:TestsRun++
  $ws = Setup-Workspace
  $prev = Get-Location
  $ok = $false
  try {
    Set-Location $ws
    & $Fn $ws | Out-Null
    $ok = $true
  } catch {
    $ok = $false
  } finally {
    Set-Location $prev
    Teardown-Workspace $ws
  }
  if ($ok) {
    "ok  $Name"
  } else {
    "FAIL $Name"
    $script:Failures++
  }
}

# --- Test stubs (bodies land in follow-up batches) ---

function Test-FreshInstallWritesPins {
  & pwsh -NoProfile -File $script:PsInstaller -Action install -Harness opencode -Source local -SkipSkills -Project | Out-Null
  if ($LASTEXITCODE -ne 0) { throw "installer failed" }
  if (-not (Test-Path ".rubber-duck/manifest.json")) { throw "manifest.json missing" }
  $d = Get-Content -Raw ".rubber-duck/manifest.json" | ConvertFrom-Json
  $pins = $d.pins
  if (-not $pins) { throw "no pins" }
  $keys = @($pins.PSObject.Properties.Name)
  if ($keys.Count -lt 3) { throw "pin count $($keys.Count) < 3" }
  foreach ($k in $keys) {
    if (-not $pins.$k.StartsWith("sha256:")) { throw "pin $k missing sha256 prefix" }
  }
}

function Test-ReinstallVerifiesPins {
  & pwsh -NoProfile -File $script:PsInstaller -Action install -Harness opencode -Source local -SkipSkills -Project | Out-Null
  if ($LASTEXITCODE -ne 0) { throw "first install failed" }
  $beforeMtime = (Get-Item ".opencode/agents/rubber-duck.md").LastWriteTimeUtc
  Start-Sleep -Seconds 1
  & pwsh -NoProfile -File $script:PsInstaller -Action install -Harness opencode -Source local -SkipSkills -Project | Out-Null
  if ($LASTEXITCODE -ne 0) { throw "reinstall failed" }
  $afterMtime = (Get-Item ".opencode/agents/rubber-duck.md").LastWriteTimeUtc
  if ($beforeMtime -ne $afterMtime) { throw "mtime changed: $beforeMtime -> $afterMtime" }
}
function Test-SyncRoundTrip          { throw "not implemented" }
function Test-RawBaseAllowlist {
  & pwsh -NoProfile -File $script:PsInstaller -Action install -Harness opencode -Source web -RawBase "https://evil.example/foo" -SkipSkills -Project 2>&1 | Out-Null
  if ($LASTEXITCODE -eq 0) { throw "expected non-allowlisted rawBase to fail" }
  $out = & pwsh -NoProfile -File $script:PsInstaller -Action install -Harness opencode -Source web -RawBase "https://evil.example/foo" -SkipSkills -Project -AllowUntrustedSource 2>&1
  if (-not ($out -match "allowlist bypassed")) { throw "expected allowlist bypassed warning" }
}
function Test-ClaudeTwoFileLayout    { throw "not implemented" }
function Test-DryRunNoWrites         { throw "not implemented" }
function Test-DryRunMultiTargetLayout{ throw "not implemented" }

# --- Test runner ---
Run-Test "fresh install writes pins"        { Test-FreshInstallWritesPins }
Run-Test "reinstall verifies pins silently" { Test-ReinstallVerifiesPins  }
Run-Test "sync round-trip"                  { Test-SyncRoundTrip          }
Run-Test "rawBase allowlist"                { Test-RawBaseAllowlist       }
Run-Test "claude two-file layout"           { Test-ClaudeTwoFileLayout    }
Run-Test "dry-run no writes"                { Test-DryRunNoWrites         }
Run-Test "dry-run multi-target layout"      { Test-DryRunMultiTargetLayout}

"`n$($script:TestsRun - $script:Failures)/$($script:TestsRun) passed, $($script:Failures) failed"
if ($script:Failures -gt 0) { exit 1 } else { exit 0 }
