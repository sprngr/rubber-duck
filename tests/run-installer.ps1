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
function Test-SyncRoundTrip {
  & pwsh -NoProfile -File $script:PsInstaller -Action install -Harness opencode -Source local -SkipSkills -Project | Out-Null
  if ($LASTEXITCODE -ne 0) { throw "install failed" }
  if (-not (Test-Path ".opencode/agents/rubber-duck.md")) { throw "opencode agent missing" }
  $manifestPath = ".rubber-duck/manifest.json"
  $d = Get-Content -Raw $manifestPath | ConvertFrom-Json -AsHashtable
  $d["targets"]["opencode"]["enabled"] = $false
  $d["targets"]["claude"] = @{ enabled = $true; scope = "project"; installAgentsMd = $true; installSkills = $false; extras = $false }
  $d | ConvertTo-Json -Depth 10 | Set-Content -Path $manifestPath
  & pwsh -NoProfile -File $script:PsInstaller -Action sync -Project -Prune -Source local -SkipSkills | Out-Null
  if ($LASTEXITCODE -ne 0) { throw "sync failed" }
  if (-not (Test-Path ".claude/agents/rubber-duck.md")) { throw "claude agent missing after sync" }
  if (Test-Path ".opencode/agents/rubber-duck.md") { throw "opencode agent not pruned" }
}
function Test-RawBaseAllowlist {
  & pwsh -NoProfile -File $script:PsInstaller -Action install -Harness opencode -Source web -RawBase "https://evil.example/foo" -SkipSkills -Project 2>&1 | Out-Null
  if ($LASTEXITCODE -eq 0) { throw "expected non-allowlisted rawBase to fail" }
  $out = & pwsh -NoProfile -File $script:PsInstaller -Action install -Harness opencode -Source web -RawBase "https://evil.example/foo" -SkipSkills -Project -AllowUntrustedSource 2>&1
  if (-not ($out -match "allowlist bypassed")) { throw "expected allowlist bypassed warning" }
}
function Test-ClaudeTwoFileLayout {
  & pwsh -NoProfile -File $script:PsInstaller -Action install -Harness claude -Source local -SkipSkills -Project | Out-Null
  if ($LASTEXITCODE -ne 0) { throw "install failed" }
  if (-not (Test-Path "CLAUDE.md")) { throw "CLAUDE.md missing" }
  if (-not (Test-Path "AGENTS.md")) { throw "AGENTS.md missing" }
  if (-not (Test-Path ".claude/agents/rubber-duck.md")) { throw "claude agent missing" }
  $d = Get-Content -Raw ".rubber-duck/manifest.json" | ConvertFrom-Json
  $pins = $d.pins
  if (-not $pins."dist/claude/CLAUDE.md") { throw "claude policy pin missing" }
  if (-not $pins."dist/claude/agents/rubber-duck-lite.md") { throw "claude lite agent pin missing" }
}
function Test-DryRunNoWrites {
  & pwsh -NoProfile -File $script:PsInstaller -Action install -Harness opencode -Source local -SkipSkills -Project -DryRun | Out-Null
  if ($LASTEXITCODE -ne 0) { throw "dry-run install failed" }
  if (Test-Path ".rubber-duck/manifest.json") { throw "manifest.json created in dry-run" }
  if (Test-Path ".opencode") { throw ".opencode created in dry-run" }
  if (Test-Path "AGENTS.md") { throw "AGENTS.md created in dry-run" }
  if (Get-ChildItem -Filter "AGENTS.md.bak.*" -ErrorAction SilentlyContinue) { throw "backup created in dry-run" }
}
function Test-DryRunMultiTargetLayout {
  $out = & pwsh -NoProfile -File $script:PsInstaller -Action install -Harness opencode,claude,copilot -Source local -SkipSkills -Project -DryRun 2>&1 | Out-String
  if ($LASTEXITCODE -ne 0) { throw "dry-run failed" }
  foreach ($needle in @("version: ", "[opencode]", "[claude]", "[copilot]", "[dry-run] pins update", "🦆 quack")) {
    if (-not $out.Contains($needle)) { throw "missing marker: $needle" }
  }
  if (Test-Path ".rubber-duck/manifest.json") { throw "manifest.json created" }
  if (Test-Path ".opencode") { throw ".opencode created" }
  if (Test-Path ".claude") { throw ".claude created" }
  if (Test-Path ".github/agents") { throw ".github/agents created" }
}

# Sync with default source (auto). Regression guard for RawBase ordering bug:
# sync path used to call Test-RawBaseAllowed before RawBase default was applied.
function Test-SyncDefaultSource {
  & pwsh -NoProfile -File $script:PsInstaller -Action install -Harness opencode -Source local -SkipSkills -Policy self -Project | Out-Null
  if ($LASTEXITCODE -ne 0) { throw "install failed" }
  & pwsh -NoProfile -File $script:PsInstaller -Action sync -Project -SkipSkills -Policy self | Out-Null
  if ($LASTEXITCODE -ne 0) { throw "sync with default source failed" }
}

# Optional Windows PowerShell compatibility hook.
# Runs only when powershell.exe exists.
function Test-WinPsManifestStructure {
  if (-not $IsWindows) { return }
  $winPs = Get-Command "powershell.exe" -ErrorAction SilentlyContinue
  if (-not $winPs) { return }

  $cmd = "& '$($script:PsInstaller)' -Action install -Harness 'opencode,copilot,claude' -Extras -Source local -SkipSkills -Project"
  & $winPs.Source -NoProfile -ExecutionPolicy Bypass -Command $cmd | Out-Null
  if ($LASTEXITCODE -ne 0) { throw "Windows PowerShell install failed" }

  if (-not (Test-Path ".rubber-duck/manifest.json")) { throw "manifest.json missing" }
  $m = Get-Content -Raw ".rubber-duck/manifest.json" | ConvertFrom-Json
  $manifestKeys = @($m.PSObject.Properties.Name)
  foreach ($k in @("schemaVersion","source","targets","pins")) {
    if (-not ($manifestKeys -contains $k)) { throw "manifest missing key: $k" }
  }
  $targetKeys = @($m.targets.PSObject.Properties.Name)
  foreach ($t in @("opencode","copilot","claude")) {
    if (-not ($targetKeys -contains $t)) { throw "manifest missing target: $t" }
  }
  if (@($m.pins.PSObject.Properties.Name).Count -eq 0) { throw "pins empty" }
}

function Test-SyncWrapperContent {
  & pwsh -NoProfile -File $script:PsInstaller -Action install -Harness opencode -Source local -SkipSkills -Project | Out-Null
  if ($LASTEXITCODE -ne 0) { throw "install failed" }
  $wrapper = ".rubber-duck/sync-latest.ps1"
  if (-not (Test-Path $wrapper)) { throw "sync wrapper missing" }
  $content = Get-Content -Raw $wrapper
  if (-not $content.Contains("-Project")) { throw "scope flag not substituted" }
  if ($content.Contains("{{SYNC_SCOPE_ARG}}")) { throw "scope token not replaced" }
  if ($content.Contains("{{SYNC_INSTALLER_URL}}")) { throw "URL token not replaced" }
  if (-not $content.Contains("RUBBER_DUCK_VERSION:")) { throw "version marker missing" }
}

# --- Test runner ---
Run-Test "fresh install writes pins"        { Test-FreshInstallWritesPins }
Run-Test "reinstall verifies pins silently" { Test-ReinstallVerifiesPins  }
Run-Test "sync round-trip"                  { Test-SyncRoundTrip          }
Run-Test "rawBase allowlist"                { Test-RawBaseAllowlist       }
Run-Test "claude two-file layout"           { Test-ClaudeTwoFileLayout    }
Run-Test "dry-run no writes"                { Test-DryRunNoWrites         }
Run-Test "dry-run multi-target layout"      { Test-DryRunMultiTargetLayout}
Run-Test "sync default source"              { Test-SyncDefaultSource      }
Run-Test "winps manifest structure"         { Test-WinPsManifestStructure }
Run-Test "sync wrapper content"             { Test-SyncWrapperContent     }

"`n$($script:TestsRun - $script:Failures)/$($script:TestsRun) passed, $($script:Failures) failed"
if ($script:Failures -gt 0) { exit 1 } else { exit 0 }
