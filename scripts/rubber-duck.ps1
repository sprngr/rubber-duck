param(
  [ValidateSet("install","uninstall","status","doctor","sync")]
  [string]$Action = "install",
  [switch]$OpenCode,
  [switch]$Copilot,
  [switch]$Claude,
  [string]$Harness,
  [switch]$Global,
  [switch]$Project = $true,
  [string]$ClaudeMd,
  [string]$Branch = "main",
  [switch]$SkipSkills,
  [switch]$SkipAgentsMd,
  [switch]$Extras,
  [switch]$DryRun,
  [switch]$Prune,
  [switch]$AllowUntrustedSource,
  [ValidateSet("auto","local","web")]
  [string]$Source = "auto",
  [string]$RawBase = ""
)

$ProjectSpecified = $MyInvocation.BoundParameters.ContainsKey("Project")
$GlobalSpecified = $MyInvocation.BoundParameters.ContainsKey("Global")

function rubber-duck {
  $LegacyTargets = @()
  if ($OpenCode) { $LegacyTargets += "opencode" }
  if ($Copilot) { $LegacyTargets += "copilot" }
  if ($Claude) { $LegacyTargets += "claude" }
  $LegacyTargetCount = $LegacyTargets.Count
  $SelectedTargets = @()

  if (-not [string]::IsNullOrWhiteSpace($Harness)) {
    if ($LegacyTargetCount -gt 0) {
      throw "Cannot combine -Harness with -OpenCode/-Copilot/-Claude."
    }
    foreach ($raw in ($Harness -split ",")) {
      $name = $raw.Trim().ToLowerInvariant()
      if ([string]::IsNullOrWhiteSpace($name)) { continue }
      if ($name -in @("opencode","copilot","claude")) {
        $SelectedTargets += $name
      } else {
        throw "Invalid harness in -Harness: $name"
      }
    }
    if ($SelectedTargets.Count -eq 0) {
      throw "Harness list is empty. Use opencode,copilot,claude."
    }
  } else {
    if ($Action -ne "sync") {
      if ($LegacyTargetCount -eq 0) {
        throw "Must specify target via -Harness or one legacy target flag."
      }
      if ($LegacyTargetCount -gt 1) {
        throw "Cannot combine multiple legacy targets. Use -Harness for multi-target."
      }
      $SelectedTargets += $LegacyTargets[0]
    }
  }

  if ($Prune -and $Action -ne "sync") {
    throw "-Prune is only valid with sync."
  }
  if (-not [string]::IsNullOrWhiteSpace($ClaudeMd) -and -not ($SelectedTargets -contains "claude")) {
    throw "-ClaudeMd applies only when claude target is selected."
  }
  if ($Action -eq "sync") {
    $SyncScriptPath = $PSCommandPath
    if ([string]::IsNullOrWhiteSpace($SyncScriptPath)) {
      $SyncScriptPath = $MyInvocation.PSCommandPath
    }
    $ManifestPath = if ($Project) { ".rubber-duck/manifest.json" } else { (Join-Path $HOME ".config/rubber-duck/manifest.json") }
    if (-not (Test-Path $ManifestPath)) {
      throw "Manifest missing: $ManifestPath. Run install first."
    }
    if ([string]::IsNullOrWhiteSpace($SyncScriptPath)) {
      throw "sync requires file-backed execution (not piped)."
    }
    if (-not (Test-RawBaseAllowed $RawBase $Source)) {
      throw "rawBase not in allowlist: $RawBase. Use -AllowUntrustedSource to override."
    }
    $manifest = Get-Content -Raw $ManifestPath | ConvertFrom-Json -AsHashtable
    $syncTargets = @()
    $syncTargetSet = @{}
    if ($manifest.ContainsKey("targets") -and $null -ne $manifest["targets"]) {
      foreach ($kv in $manifest["targets"].GetEnumerator()) {
        $cfg = $kv.Value
        if ($null -eq $cfg -or -not $cfg.ContainsKey("enabled") -or [bool]$cfg["enabled"]) {
          $syncTargets += $kv.Key
          $syncTargetSet[$kv.Key] = $true
        }
      }
    }
    if ($syncTargets.Count -eq 0) {
      Write-Host "sync: no enabled targets in manifest"
      if (-not $Prune) { return }
    }
    foreach ($t in $syncTargets) {
      $args = @("-File", $SyncScriptPath, "-Action", "install", "-Harness", $t, "-Source", $Source, "-Branch", $Branch, "-RawBase", $RawBase)
      if ($Project) { $args += "-Project" } else { $args += "-Global" }
      if ($SkipSkills) { $args += "-SkipSkills" }
      if ($SkipAgentsMd) { $args += "-SkipAgentsMd" }
      if ($Extras) { $args += "-Extras" }
      if ($DryRun) { $args += "-DryRun" }
      if ($AllowUntrustedSource) { $args += "-AllowUntrustedSource" }
      & pwsh @args
      if ($LASTEXITCODE -ne 0) { throw "sync install failed for target: $t" }
    }
    if ($Prune) {
      foreach ($t in @("opencode","copilot","claude")) {
        if (-not $syncTargetSet.ContainsKey($t)) {
          $args = @("-File", $SyncScriptPath, "-Action", "uninstall", "-Harness", $t, "-Source", $Source, "-Branch", $Branch, "-RawBase", $RawBase, "-SkipSkills")
          if ($Project) { $args += "-Project" } else { $args += "-Global" }
          if ($SkipAgentsMd) { $args += "-SkipAgentsMd" }
          if ($DryRun) { $args += "-DryRun" }
          if ($AllowUntrustedSource) { $args += "-AllowUntrustedSource" }
          & pwsh @args
          if ($LASTEXITCODE -ne 0) { throw "sync prune uninstall failed for target: $t" }
        }
      }
    }
    Write-Host "sync: complete"
    return
  }
  $script:SelectedTargets = $SelectedTargets

# Scope flags are mutually exclusive.
if ($ProjectSpecified -and $GlobalSpecified) {
  throw "Cannot combine -Project and -Global."
}

# Project default, global override
if ($Global) {
  $Project = $false;
}
# Parameters are declared in the top-level param() block and read from script scope here.
$ErrorActionPreference = "Stop"

# Pinned npx CLI package spec (mirrors SKILLS_CLI in rubber-duck.sh)
$SkillsCli = "skills@^1.5.21"

# SkillsSource derived from -Source after Resolve-Source
$SkillsSource = ""

# Update RawBase based on branch
if ($Branch -eq "main" -and -not [string]::IsNullOrWhiteSpace($env:BASH_SOURCE_URL)) {
  $m = [regex]::Match($env:BASH_SOURCE_URL, 'githubusercontent\.com/[^/]+/[^/]+/([^/]+)/')
  if ($m.Success) {
    $detected = $m.Groups[1].Value
    if (-not [string]::IsNullOrWhiteSpace($detected) -and $detected -ne "main") {
      $Branch = $detected
      Write-Host "Auto-detected branch: $Branch"
    }
  }
}
if ([string]::IsNullOrWhiteSpace($RawBase)) {
  $RawBase = "https://raw.githubusercontent.com/sprngr/rubber-duck/$Branch"
}
if ($Branch -ne "main") {
  Write-Host "Using branch: $Branch"
}

# When run via `iwr | iex` there is no backing script file path.
# In function scope, $MyInvocation.MyCommand.Path can also be empty even for file execution.
# Use script path variables first, then classify piped mode only if still empty.
$ScriptPath = $PSCommandPath
if ([string]::IsNullOrWhiteSpace($ScriptPath)) {
  $ScriptPath = $MyInvocation.PSCommandPath
}
$script:RunningPiped = [string]::IsNullOrWhiteSpace($ScriptPath)
if ($script:RunningPiped) {
  $ScriptDir = [System.IO.Path]::GetTempPath()
  $RepoRoot = [System.IO.Path]::GetTempPath()
} else {
  $ScriptDir = Split-Path -Parent $ScriptPath
  $RepoRoot = Split-Path -Parent $ScriptDir
}
$LocalAgentsDir = $null
$LocalPolicyFile = $null
$LocalAgentsPolicyFile = $null
$RemoteAgentsPath = $null
$RemotePolicyPath = $null
$RemoteAgentsPolicyPath = $null
$PolicyMode = "managed_block"  # managed_block|file
$script:CanonicalVersion = "unknown"

$ManagedStart = "<!-- RUBBER_DUCK_MANAGED_BLOCK START -->"
$ManagedEnd = "<!-- RUBBER_DUCK_MANAGED_BLOCK END -->"

# Built agent filenames are identical across harnesses (<name>.md)
$AgentFiles = @(
  "rubber-duck.md",
  "duckling.md"
)

$DefaultSkills = @(
  "duck-debt",
  "duck-debug",
  "duck-design",
  "duck-patch",
  "duck-refactor",
  "duck-review",
  "duck-risk",
  "duck-simplify",
  "duck-teach",
  "duck-triage",
  "quack"
)

# Optional extras: installed only with -Extras.
$ExtrasSkills = @(
  "duck-adapt",
  "duck-grill",
  "duck-tape"
)

function Log($msg) { Write-Host $msg }
function Warn($msg) { Write-Warning $msg }

# Exact rawBase prefix required unless -AllowUntrustedSource is set.
$AllowedRawBasePrefix = "https://raw.githubusercontent.com/sprngr/rubber-duck"

# Compute SHA-256 of a file, return "sha256:<hex>". Returns $null on error.
function Get-Sha256([string]$Path) {
  if (-not (Test-Path $Path)) { return $null }
  $h = (Get-FileHash -Algorithm SHA256 -Path $Path).Hash.ToLowerInvariant()
  return "sha256:$h"
}

# Validate rawBase against $AllowedRawBasePrefix. Skip check for local mode.
# Honor -AllowUntrustedSource override. Returns $true if allowed, $false otherwise.
function Test-RawBaseAllowed([string]$RawBaseUrl, [string]$Mode) {
  if ($Mode -eq "local") { return $true }
  if ($AllowUntrustedSource) {
    Warn "rawBase allowlist bypassed: $RawBaseUrl"
    return $true
  }
  return $RawBaseUrl.StartsWith($AllowedRawBasePrefix)
}

# Verify artifact file matches manifest pin.
# Returns 0 on match, 1 on mismatch, 2 if pin missing.
function Test-Pin([string]$ArtifactPath, [string]$LocalFile) {
  if ([string]::IsNullOrWhiteSpace($ArtifactPath) -or [string]::IsNullOrWhiteSpace($LocalFile)) { return 2 }
  $mp = if ($Project) { ".rubber-duck/manifest.json" } else { (Join-Path $HOME ".config/rubber-duck/manifest.json") }
  if (-not (Test-Path $mp)) { return 2 }
  $expected = ""
  try {
    $data = Get-Content -Raw $mp | ConvertFrom-Json -AsHashtable
    if ($data -and $data.ContainsKey("pins") -and $data["pins"].ContainsKey($ArtifactPath)) {
      $expected = [string]$data["pins"][$ArtifactPath]
    }
  } catch { }
  if ([string]::IsNullOrWhiteSpace($expected)) { return 2 }
  if (-not (Test-Path $LocalFile)) { return 1 }
  $actual = Get-Sha256 $LocalFile
  if ($actual -ne $expected) {
    Write-Host "ERROR: pin mismatch for ${ArtifactPath}: expected $expected, got $actual"
    return 1
  }
  return 0
}

# Write pins block into manifest. $Pairs is hashtable of artifactPath -> sha256:<hex>.
function Write-Pins([string]$ManifestPath, [hashtable]$Pairs) {
  if ($null -eq $Pairs -or $Pairs.Count -eq 0) { return }
  $data = @{}
  if (Test-Path $ManifestPath) {
    try { $data = Get-Content -Raw $ManifestPath | ConvertFrom-Json -AsHashtable } catch { $data = @{} }
  }
  if ($null -eq $data) { $data = @{} }
  if (-not $data.ContainsKey("pins") -or $null -eq $data["pins"]) { $data["pins"] = @{} }
  foreach ($k in $Pairs.Keys) { $data["pins"][$k] = $Pairs[$k] }
  $data | ConvertTo-Json -Depth 10 | Set-Content -Path $ManifestPath
}

# Warn when lastAppliedVersion is newer than sourceRef being installed.
function Warn-OnDowngrade([string]$LastApplied, [string]$Incoming) {
  if ([string]::IsNullOrWhiteSpace($LastApplied) -or $LastApplied -eq "v0.0.0" -or $LastApplied -eq $Incoming) { return }
  try {
    $la = [version]($LastApplied.TrimStart('v'))
    $inc = [version]($Incoming.TrimStart('v'))
    if ($la -gt $inc) { Warn "downgrade: manifest lastAppliedVersion $LastApplied > incoming $Incoming" }
  } catch { }
}

function Get-VersionFromFile([string]$Path) {
  if (-not (Test-Path $Path)) { return $null }
  $m = Select-String -Path $Path -Pattern 'RUBBER_DUCK_VERSION:\s*(v[0-9]+\.[0-9]+\.[0-9]+)' | Select-Object -First 1
  if ($null -eq $m) { return $null }
  return $m.Matches[0].Groups[1].Value
}

function Resolve-Target {
  if ($OpenCode) {
    $script:Target = "opencode"
    if ($Project) {
      $script:DestAgentsDir = ".opencode/agents"
      $script:DestPolicyMd = "AGENTS.md"
    } else {
      $script:DestAgentsDir = Join-Path $HOME ".config/opencode/agents"
      $script:DestPolicyMd = Join-Path $HOME ".config/opencode/AGENTS.md"
    }
    $script:PolicyMode = "managed_block"
    $script:LocalPolicyFile = Join-Path $RepoRoot "dist/AGENTS.md"
    if (Test-Path (Join-Path $RepoRoot "dist/opencode/agents")) {
      $script:LocalAgentsDir = Join-Path $RepoRoot "dist/opencode/agents"
    } else {
      $script:LocalAgentsDir = Join-Path $RepoRoot "agents"
    }
    $script:RemotePolicyPath = "dist/AGENTS.md"
    $script:RemoteAgentsPath = "dist/opencode/agents"
    return
  }

  if ($Claude) {
    $script:Target = "claude"
    if ($Project) {
      $script:DestAgentsDir = ".claude/agents"
      $script:DestPolicyMd = if ([string]::IsNullOrWhiteSpace($ClaudeMd)) { "CLAUDE.md" } else { $ClaudeMd }
    } else {
      $script:DestAgentsDir = Join-Path $HOME ".claude/agents"
      $script:DestPolicyMd = if ([string]::IsNullOrWhiteSpace($ClaudeMd)) { (Join-Path $HOME ".claude/CLAUDE.md") } else { $ClaudeMd }
    }
    $policyParent = Split-Path -Parent $script:DestPolicyMd
    if ([string]::IsNullOrWhiteSpace($policyParent)) { $policyParent = "." }
    $script:DestClaudeAgentsMd = Join-Path $policyParent "AGENTS.md"
    $script:PolicyMode = "file"
    $script:LocalPolicyFile = Join-Path $RepoRoot "dist/claude/CLAUDE.md"
    $script:LocalAgentsPolicyFile = Join-Path $RepoRoot "dist/AGENTS.md"
    $script:LocalAgentsDir = Join-Path $RepoRoot "dist/claude/agents"
    $script:RemotePolicyPath = "dist/claude/CLAUDE.md"
    $script:RemoteAgentsPolicyPath = "dist/AGENTS.md"
    $script:RemoteAgentsPath = "dist/claude/agents"
    return
  }

  if ($Copilot) {
    $script:Target = "copilot"
    if ($Project) {
      $script:DestAgentsDir = ".github/agents"
      $script:DestPolicyMd = "AGENTS.md"
    } else {
      $script:DestAgentsDir = Join-Path $HOME ".copilot/agents"
      $script:DestPolicyMd = Join-Path $HOME ".copilot/AGENTS.md"
    }
    $script:PolicyMode = "managed_block"
    $script:LocalPolicyFile = Join-Path $RepoRoot "dist/AGENTS.md"
    if (Test-Path (Join-Path $RepoRoot "dist/copilot/agents")) {
      $script:LocalAgentsDir = Join-Path $RepoRoot "dist/copilot/agents"
    } else {
      $script:LocalAgentsDir = Join-Path $RepoRoot "agents"
    }
    $script:RemotePolicyPath = "dist/AGENTS.md"
    $script:RemoteAgentsPath = "dist/copilot/agents"
    return
  }

  throw "Internal error: target resolution reached fallback unexpectedly."
}

function Has-LocalSources {
  if (-not (Test-Path $script:LocalPolicyFile)) { return $false }
  if ($script:PolicyMode -eq "file" -and -not (Test-Path $script:LocalAgentsPolicyFile)) { return $false }
  foreach ($f in $AgentFiles) {
    if (-not (Test-Path (Join-Path $script:LocalAgentsDir $f))) { return $false }
  }
  return $true
}

function Resolve-Source {
  switch ($Source) {
    "local" {
      if ($script:RunningPiped) {
        throw "local source selected but no repo checkout is available (running via iwr|iex). Use -Source web or run from a repo checkout."
      }
      $script:EffectiveSource = "local"
    }
    "web" { $script:EffectiveSource = "web" }
    "auto" {
      if ($script:RunningPiped) {
        $script:EffectiveSource = "web"
      } elseif (Has-LocalSources) {
        $script:EffectiveSource = "local"
      } else {
        $script:EffectiveSource = "web"
      }
    }
  }
}

function Download-Sources {
  $script:TmpDir = Join-Path ([System.IO.Path]::GetTempPath()) ("rubber-duck-" + [guid]::NewGuid().ToString())
  New-Item -ItemType Directory -Force -Path $script:TmpDir | Out-Null

  if ($script:EffectiveSource -eq "local") {
    if ($script:PolicyMode -eq "managed_block") {
      Copy-Item -Force $script:LocalPolicyFile (Join-Path $script:TmpDir "AGENTS.md")
    } else {
      Copy-Item -Force $script:LocalPolicyFile (Join-Path $script:TmpDir "CLAUDE.md")
      Copy-Item -Force $script:LocalAgentsPolicyFile (Join-Path $script:TmpDir "AGENTS.md")
    }
    foreach ($f in $AgentFiles) {
      Copy-Item -Force (Join-Path $script:LocalAgentsDir $f) (Join-Path $script:TmpDir $f)
    }
    $v = Get-VersionFromFile (Join-Path $script:TmpDir "AGENTS.md")
    if (-not [string]::IsNullOrWhiteSpace($v)) { $script:CanonicalVersion = $v }
    Log "source: local ($RepoRoot)"
    return
  }

  if ($script:PolicyMode -eq "managed_block") {
    Invoke-WebRequest -UseBasicParsing -Uri "$RawBase/$($script:RemotePolicyPath)" -OutFile (Join-Path $script:TmpDir "AGENTS.md")
  } else {
    Invoke-WebRequest -UseBasicParsing -Uri "$RawBase/$($script:RemotePolicyPath)" -OutFile (Join-Path $script:TmpDir "CLAUDE.md")
    Invoke-WebRequest -UseBasicParsing -Uri "$RawBase/$($script:RemoteAgentsPolicyPath)" -OutFile (Join-Path $script:TmpDir "AGENTS.md")
  }
  foreach ($f in $AgentFiles) {
    Invoke-WebRequest -UseBasicParsing -Uri "$RawBase/$($script:RemoteAgentsPath)/$f" -OutFile (Join-Path $script:TmpDir $f)
  }
  $v = Get-VersionFromFile (Join-Path $script:TmpDir "AGENTS.md")
  if (-not [string]::IsNullOrWhiteSpace($v)) { $script:CanonicalVersion = $v }
  Log "source: web ($RawBase)"
}

function Cleanup-Sources {
  if ($script:TmpDir -and (Test-Path $script:TmpDir)) {
    Remove-Item -Recurse -Force $script:TmpDir
  }
}

function Strip-ManagedBlockText([string]$text) {
  $lines = $text -split "`r?`n"
  $out = New-Object System.Collections.Generic.List[string]
  $inBlock = $false
  foreach ($line in $lines) {
    if ($line -eq $ManagedStart) { $inBlock = $true; continue }
    if ($line -eq $ManagedEnd) { $inBlock = $false; continue }
    if (-not $inBlock) { $out.Add($line) }
  }
  return ($out -join "`n")
}

function Backup-Md([string]$Target) {
  if ($DryRun) {
    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    Log "[dry-run] backup $Target -> $Target.bak.$stamp"
    return
  }
  $parent = Split-Path -Parent $Target
  if (-not [string]::IsNullOrWhiteSpace($parent)) {
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
  }
  $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
  $backup = "$Target.bak.$stamp"
  if (Test-Path $Target) {
    Copy-Item -Force $Target $backup
  } else {
    New-Item -ItemType File -Force -Path $backup | Out-Null
  }
  $allBackups = Get-ChildItem -Path "$Target.bak.*" -ErrorAction SilentlyContinue | Sort-Object Name
  if ($allBackups.Count -gt 1) {
    $toDelete = $allBackups | Select-Object -First ($allBackups.Count - 1)
    foreach ($b in $toDelete) {
      Remove-Item -Force $b.FullName
    }
  }
  Log "Backup created: $backup"
}

function Upsert-ManagedBlock([string]$Target, [string]$ContentFile) {
  if ($SkipAgentsMd) { return }
  if ($DryRun) { Log "[dry-run] upsert managed block in $Target"; return }
  $parent = Split-Path -Parent $Target
  if (-not [string]::IsNullOrWhiteSpace($parent)) {
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
  }
  if (-not (Test-Path $Target)) { New-Item -ItemType File -Force -Path $Target | Out-Null }
  $current = if (Test-Path $Target) { Get-Content -Raw $Target } else { "" }
  $stripped = Strip-ManagedBlockText $current
  $stripped = $stripped -replace "(\r?\n)+$",""
  $policy = Get-Content -Raw $ContentFile
  $policy = $policy -replace "(\r?\n)+$",""
  $parts = New-Object System.Collections.Generic.List[string]
  if (-not [string]::IsNullOrWhiteSpace($stripped)) {
    $parts.Add($stripped)
    $parts.Add("")
  }
  $parts.Add($ManagedStart)
  if (-not [string]::IsNullOrEmpty($policy)) { $parts.Add($policy) }
  $parts.Add($ManagedEnd)
  $next = ($parts -join "`n")
  Set-Content -Path $Target -Value $next
}

function Remove-ManagedBlock([string]$Target) {
  if ($SkipAgentsMd) { return }
  if ($DryRun) { Log "[dry-run] remove managed block from $Target"; return }
  if (-not (Test-Path $Target)) { return }
  $current = Get-Content -Raw $Target
  $stripped = Strip-ManagedBlockText $current
  Set-Content -Path $Target -Value $stripped
}

function Install-PolicyFile {
  if ($SkipAgentsMd) { return }
  # Claude targets keep a two-file layout (CLAUDE.md -> @AGENTS.md include,
  # AGENTS.md -> policy). Upsert managed blocks into both so user-authored
  # content in either file is preserved instead of clobbered.
  Upsert-ManagedBlock $DestClaudeAgentsMd (Join-Path $script:TmpDir "AGENTS.md")
  Upsert-ManagedBlock $DestPolicyMd (Join-Path $script:TmpDir "CLAUDE.md")
  Log "Installed policy block -> $DestPolicyMd"
  Log "Installed policy block -> $DestClaudeAgentsMd"
}

function Remove-PolicyFile {
  if ($SkipAgentsMd) { return }
  # Strip only our managed blocks; user content in these files is left intact.
  Remove-ManagedBlock $DestPolicyMd
  Remove-ManagedBlock $DestClaudeAgentsMd
  Log "Removed policy block from $DestPolicyMd"
  Log "Removed policy block from $DestClaudeAgentsMd"
}

function Install-Agents {
  if ($DryRun) {
    Log "[dry-run] ensure dir $DestAgentsDir"
    foreach ($f in $AgentFiles) {
      Log "[dry-run] cp $(Join-Path $script:TmpDir $f) -> $(Join-Path $DestAgentsDir $f)"
    }
    return
  }
  New-Item -ItemType Directory -Force -Path $DestAgentsDir | Out-Null
  foreach ($f in $AgentFiles) {
    Copy-Item -Force (Join-Path $script:TmpDir $f) (Join-Path $DestAgentsDir $f)
  }
  Log "Installed $($AgentFiles.Count) agents -> $DestAgentsDir"
}

function Uninstall-Agents {
  if ($DryRun) {
    foreach ($f in $AgentFiles) {
      Log "[dry-run] rm $(Join-Path $DestAgentsDir $f)"
    }
    return
  }
  $removed = 0
  foreach ($f in $AgentFiles) {
    $dest = Join-Path $DestAgentsDir $f
    if (Test-Path $dest) {
      Remove-Item -Force $dest
      $removed++
    }
  }
  Log "Removed $removed agents from $DestAgentsDir"
}

function Skills-Install {
  if ($SkipSkills) { return }
  if ($DryRun) {
    $installList = @() + $DefaultSkills
    if ($Extras) { $installList += $ExtrasSkills }
    $scope = if ($Project) { @() } else { @("-g") }
    Log "[dry-run] npx $SkillsCli add $SkillsSource --skill $($installList -join ' ') $($scope -join ' ') -y"
    return
  }
  if (-not (Get-Command npx -ErrorAction SilentlyContinue)) {
    Warn "npx not found; skipping skills install"
    return
  }
  $installList = @() + $DefaultSkills
  if ($Extras) { $installList += $ExtrasSkills }
  $scope = if ($Project) { @() } else { @("-g") }
  $args = @("--yes", $SkillsCli, "add", $SkillsSource, "--skill") + $installList + $scope
  & npx @args
}

function Skills-Uninstall {
  if ($SkipSkills) { return }
  if ($DryRun) {
    $allSkills = @() + $DefaultSkills + $ExtrasSkills
    $scope = if ($Project) { @() } else { @("-g") }
    Log "[dry-run] npx $SkillsCli remove $SkillsSource --skill $($allSkills -join ' ') $($scope -join ' ') -y"
    return
  }
  if (-not (Get-Command npx -ErrorAction SilentlyContinue)) {
    Warn "npx not found; skipping skills uninstall"
    return
  }
  $allSkills = @() + $DefaultSkills + $ExtrasSkills
  $scope = if ($Project) { @() } else { @("-g") }
  try {
    $args = @("--yes", $SkillsCli, "remove", $SkillsSource, "--skill") + $allSkills + $scope
    & npx @args
  } catch {
    Warn "skills remove failed; remove package manually if needed"
  }
}

function Skills-Status {
  if ($SkipSkills) { Log "skills: skipped (-SkipSkills)"; return }
  if (-not (Get-Command npx -ErrorAction SilentlyContinue)) {
    Log "skills: npx missing"
    return
  }
  $scope = if ($Project) { @() } else { @("-g") }
  $previousNoColor = $env:NO_COLOR
  try {
    $env:NO_COLOR = "1"
    $args = @("--yes", $SkillsCli, "list") + $scope
    $list = & npx @args | Out-String
    $allPresent = $true
    foreach ($skill in $DefaultSkills) {
      if ($list.IndexOf($skill, [System.StringComparison]::Ordinal) -lt 0) {
        $allPresent = $false
        break
      }
    }
    if ($allPresent) {
      Log "skills: installed ($SkillsSource)"
    } else {
      Log "skills: not detected ($SkillsSource)"
    }
    $extrasPresent = @()
    foreach ($skill in $ExtrasSkills) {
      if ($list.IndexOf($skill, [System.StringComparison]::Ordinal) -ge 0) {
        $extrasPresent += $skill
      }
    }
    $extrasSuffix = if ($extrasPresent.Count -gt 0) { " ([$($extrasPresent -join ', ')])" } else { "" }
    Log "skills extras (optional): $($extrasPresent.Count)/$($ExtrasSkills.Count) present$extrasSuffix"
  } catch {
    Log "skills: unable to query (npx skills list failed)"
  } finally {
    if ($null -eq $previousNoColor) {
      Remove-Item Env:NO_COLOR -ErrorAction SilentlyContinue
    } else {
      $env:NO_COLOR = $previousNoColor
    }
  }
}

function Has-ManagedBlock([string]$Target) {
  if (-not (Test-Path $Target)) { return $false }
  $text = Get-Content -Raw $Target
  return $text.Contains($ManagedStart) -and $text.Contains($ManagedEnd)
}

function Report-PolicyBlock([string]$Target) {
  if ($SkipAgentsMd) { Log "AGENTS policy block ($(Split-Path -Leaf $Target)): skipped (-SkipAgentsMd)"; return }
  $state = if (Has-ManagedBlock $Target) { "present" } else { "missing" }
  Log "AGENTS policy block ($(Split-Path -Leaf $Target)): $state"
}

function Status {
  $v = Get-VersionFromFile $DestPolicyMd
  if (-not [string]::IsNullOrWhiteSpace($v)) { $script:CanonicalVersion = $v }
  Log "target: $Target"
  Log "agents_dir: $DestAgentsDir"
  Log "policy_md: $DestPolicyMd"
  Log "version: $script:CanonicalVersion"
  $installed = 0
  foreach ($f in $AgentFiles) {
    if (Test-Path (Join-Path $DestAgentsDir $f)) { $installed++ }
  }
  Log "agents: $installed/$($AgentFiles.Count) present"
  Report-PolicyBlock $DestPolicyMd
  if ($PolicyMode -eq "file") { Report-PolicyBlock $DestClaudeAgentsMd }
  Skills-Status
}

function Doctor {
  Resolve-Target
  Resolve-Source
  if ($DryRun) {
    if (-not (Test-Path $DestAgentsDir)) { Warn "doctor: agents dir missing, would create: $DestAgentsDir" }
  } else {
    New-Item -ItemType Directory -Force -Path $DestAgentsDir | Out-Null
  }
  $policyParent = Split-Path -Parent $DestPolicyMd
  if (-not [string]::IsNullOrWhiteSpace($policyParent)) {
    if ($DryRun) {
      if (-not (Test-Path $policyParent)) { Warn "doctor: policy parent missing, would create: $policyParent" }
    } else {
      New-Item -ItemType Directory -Force -Path $policyParent | Out-Null
    }
  }
  if ($PolicyMode -eq "file") {
    $agentsParent = Split-Path -Parent $DestClaudeAgentsMd
    if (-not [string]::IsNullOrWhiteSpace($agentsParent)) {
      if ($DryRun) {
        if (-not (Test-Path $agentsParent)) { Warn "doctor: policy parent missing, would create: $agentsParent" }
      } else {
        New-Item -ItemType Directory -Force -Path $agentsParent | Out-Null
      }
    }
  }
  Log "doctor: ok"
}

function Update-ManifestTarget([string]$Operation, [string]$TargetName) {
  if ($Action -eq "sync") { return }
  if ($DryRun) {
    $dryManifestPath = if ($Project) { ".rubber-duck/manifest.json" } else { (Join-Path $HOME ".config/rubber-duck/manifest.json") }
    Log "[dry-run] manifest $Operation $TargetName -> $dryManifestPath"
    return
  }
  $ManifestPath = if ($Project) { ".rubber-duck/manifest.json" } else { (Join-Path $HOME ".config/rubber-duck/manifest.json") }
  $priorVersion = ""
  if (Test-Path $ManifestPath) {
    try { $priorVersion = [string](Get-Content -Raw $ManifestPath | ConvertFrom-Json -AsHashtable)["source"]["lastAppliedVersion"] } catch { }
  }
  Warn-OnDowngrade $priorVersion $script:CanonicalVersion
  $ManifestParent = Split-Path -Parent $ManifestPath
  if (-not [string]::IsNullOrWhiteSpace($ManifestParent)) {
    New-Item -ItemType Directory -Force -Path $ManifestParent | Out-Null
  }
  $manifest = @{}
  if (Test-Path $ManifestPath) {
    try { $manifest = Get-Content -Raw $ManifestPath | ConvertFrom-Json -AsHashtable } catch { $manifest = @{} }
  }
  if ($null -eq $manifest) { $manifest = @{} }
  if (-not $manifest.ContainsKey("schemaVersion")) { $manifest["schemaVersion"] = 1 }
  $manifest["source"] = @{
    mode = $script:EffectiveSource
    sourceRef = $Branch
    rawBase = $RawBase
    lastAppliedVersion = $script:CanonicalVersion
  }
  if (-not $manifest.ContainsKey("targets") -or $null -eq $manifest["targets"]) { $manifest["targets"] = @{} }
  if ($Operation -eq "install") {
    $manifest["targets"][$TargetName] = @{
      enabled = $true
      scope = $(if ($Project) { "project" } else { "global" })
      installAgentsMd = (-not $SkipAgentsMd)
      installSkills = (-not $SkipSkills)
      extras = [bool]$Extras
    }
  } elseif ($Operation -eq "uninstall") {
    [void]$manifest["targets"].Remove($TargetName)
  }
  $manifest | ConvertTo-Json -Depth 10 | Set-Content -Path $ManifestPath
}

try {
  foreach ($SelectedTarget in $script:SelectedTargets) {
    $OpenCode = $SelectedTarget -eq "opencode"
    $Copilot = $SelectedTarget -eq "copilot"
    $Claude = $SelectedTarget -eq "claude"

    Resolve-Target
    Resolve-Source
    switch ($script:EffectiveSource) {
      "local" { $SkillsSource = $RepoRoot }
      default {
        if ($Branch -eq "main") {
          $SkillsSource = "https://github.com/sprngr/rubber-duck"
        } else {
          $SkillsSource = "https://github.com/sprngr/rubber-duck#$Branch"
        }
      }
    }
    Write-Host "Skills source: $SkillsSource"
    if (-not (Test-RawBaseAllowed $RawBase $script:EffectiveSource)) {
      throw "rawBase not in allowlist: $RawBase. Use -AllowUntrustedSource to override."
    }
    switch ($Action) {
      "install" {
        Doctor
        Download-Sources
        Install-Agents
        foreach ($pinF in $AgentFiles) {
          $pinRc = Test-Pin "$($script:RemoteAgentsPath)/$pinF" (Join-Path $script:TmpDir $pinF)
          if ($pinRc -eq 1) { throw "pin verification failed" }
        }
        if (-not $SkipAgentsMd) {
          $pinPolicyTmp = Join-Path $script:TmpDir "AGENTS.md"
          if ($PolicyMode -eq "file") { $pinPolicyTmp = Join-Path $script:TmpDir "CLAUDE.md" }
          $pinRc = Test-Pin $script:RemotePolicyPath $pinPolicyTmp
          if ($pinRc -eq 1) { throw "pin verification failed" }
        }
        if (-not $SkipAgentsMd) {
          Backup-Md $DestPolicyMd
          if ($PolicyMode -eq "managed_block") {
            Upsert-ManagedBlock $DestPolicyMd (Join-Path $script:TmpDir "AGENTS.md")
          } else {
            Backup-Md $DestClaudeAgentsMd
            Install-PolicyFile
          }
        }
        Skills-Install
        Status
        Update-ManifestTarget "install" $script:Target
        $pinManifestPath = if ($Project) { ".rubber-duck/manifest.json" } else { (Join-Path $HOME ".config/rubber-duck/manifest.json") }
        $pinPairs = @{}
        foreach ($pinF in $AgentFiles) {
          $h = Get-Sha256 (Join-Path $script:TmpDir $pinF)
          if ($h) { $pinPairs["$($script:RemoteAgentsPath)/$pinF"] = $h }
        }
        if (-not $SkipAgentsMd) {
          $pinPolicyTmp = Join-Path $script:TmpDir "AGENTS.md"
          if ($PolicyMode -eq "file") { $pinPolicyTmp = Join-Path $script:TmpDir "CLAUDE.md" }
          $h = Get-Sha256 $pinPolicyTmp
          if ($h) { $pinPairs[$script:RemotePolicyPath] = $h }
        }
        Write-Pins $pinManifestPath $pinPairs
      }
      "uninstall" {
        Doctor
        Download-Sources
        Uninstall-Agents
        if (-not $SkipAgentsMd) {
          Backup-Md $DestPolicyMd
          if ($PolicyMode -eq "managed_block") {
            Remove-ManagedBlock $DestPolicyMd
          } else {
            Backup-Md $DestClaudeAgentsMd
            Remove-PolicyFile
          }
        }
        Skills-Uninstall
        Status
        Update-ManifestTarget "uninstall" $script:Target
      }
      "status" { Status }
      "doctor" { Doctor }
    }
  }
}
finally {
  Cleanup-Sources
}

}

if ($MyInvocation.InvocationName -ne '.') {
  rubber-duck
}
