param(
  [ValidateSet("install","uninstall","status","doctor","sync")]
  [string]$Action = "install",
  [switch]$OpenCode,
  [switch]$Copilot,
  [switch]$Claude,
  [string]$Harness,
  [switch]$Global,
  [switch]$Project = $true,
  [string]$Branch = "main",
  [switch]$SkipSkills,
  [switch]$Extras,
  [switch]$SessionHook,
  [switch]$DryRun,
  [switch]$Prune,
  [switch]$AllowUntrustedSource,
  [ValidateSet("auto","local","web")]
  [string]$Source = "auto",
  [string]$RawBase = ""
)

$ProjectSpecified = $MyInvocation.BoundParameters.ContainsKey("Project")
$GlobalSpecified = $MyInvocation.BoundParameters.ContainsKey("Global")

function Log($msg) { Write-Host $msg }
function Warn($msg) { Write-Warning $msg }

function Print-Banner {
  @'
          _    _                    _         _
 _ _ _  _| |__| |__  ___ _ _ ___ __| |_  _ __| |__
| '_| || | '_ \ '_ \/ -_) '_|___/ _` | || / _| / /
|_|  \_,_|_.__/_.__/\___|_|     \__,_|\_,_\__|_\_\

'@ | Write-Host
}

function Resolve-CanonicalVersion {
  if ($script:EffectiveSource -eq "local") {
    $versionFile = Join-Path $RepoRoot "VERSION"
    $v = Get-PlainVersion $versionFile
    if (-not [string]::IsNullOrWhiteSpace($v)) { $script:CanonicalVersion = $v }
  } else {
    try {
      $tmp = [System.IO.Path]::GetTempFileName()
      Invoke-WebRequest -UseBasicParsing -Uri "$RawBase/VERSION" -OutFile $tmp -ErrorAction Stop | Out-Null
      $v = Get-PlainVersion $tmp
      if (-not [string]::IsNullOrWhiteSpace($v)) { $script:CanonicalVersion = $v }
      Remove-Item -Force $tmp
    } catch { }
  }
}

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

function Get-ManifestPath {
  if ($Project) { return ".rubber-duck/manifest.json" }
  return (Join-Path $HOME ".config/rubber-duck/manifest.json")
}

# Build full sync-replay args. Mirrors bash sync_replay_cmd shape:
# helper appends install-specific flags, dry-run, and allow-untrusted so
# call sites reduce to a single invocation.
function Get-SyncReplayArgs {
  param(
    [string]$Action,
    [string]$HarnessCsv,
    [switch]$SkipSkills,
    [switch]$Extras,
    [switch]$SessionHook
  )
  $syncArgs = @("-File", (Get-SyncScriptPath), "-Action", $Action, "-Harness", $HarnessCsv, "-Source", $Source, "-Branch", $Branch, "-RawBase", $RawBase)
  if ($Project) { $syncArgs += "-Project" } else { $syncArgs += "-Global" }
  if ($Action -eq "install") {
    if ($SkipSkills) { $syncArgs += "-SkipSkills" }
    if ($Extras) { $syncArgs += "-Extras" }
    if ($SessionHook) { $syncArgs += "-SessionHook" }
  } else {
    $syncArgs += "-SkipSkills"
  }
  if ($DryRun) { $syncArgs += "-DryRun" }
  if ($AllowUntrustedSource) { $syncArgs += "-AllowUntrustedSource" }
  return $syncArgs
}

function Get-SyncScriptPath {
  $p = $PSCommandPath
  if ([string]::IsNullOrWhiteSpace($p)) { $p = $MyInvocation.PSCommandPath }
  if ([string]::IsNullOrWhiteSpace($p)) { $p = $MyInvocation.MyCommand.Path }
  return $p
}

function Get-RawBaseCheckMode {
  if (-not [string]::IsNullOrWhiteSpace($script:EffectiveSource)) {
    return $script:EffectiveSource
  }
  return $Source
}

# Convert JSON object graph into hashtable/array graph (PS 5.1 + 7+ compatible).
function Convert-ToHashtableCompat($InputObject) {
  if ($null -eq $InputObject) { return $null }
  if ($InputObject -is [hashtable]) {
    $h = @{}
    foreach ($k in $InputObject.Keys) { $h[$k] = Convert-ToHashtableCompat $InputObject[$k] }
    return $h
  }
  if ($InputObject -is [pscustomobject]) {
    $h = @{}
    foreach ($p in $InputObject.PSObject.Properties) { $h[$p.Name] = Convert-ToHashtableCompat $p.Value }
    return $h
  }
  if ($InputObject -is [System.Collections.IList]) {
    $arr = @()
    foreach ($i in $InputObject) { $arr += ,(Convert-ToHashtableCompat $i) }
    return $arr
  }
  return $InputObject
}

function Read-JsonAsHashtable([string]$Path) {
  if (-not (Test-Path $Path)) { return @{} }
  try {
    $obj = Get-Content -Raw $Path | ConvertFrom-Json
    $data = Convert-ToHashtableCompat $obj
    if ($null -eq $data) { return @{} }
    return $data
  } catch { return @{} }
}

# Write pins block into manifest. $Pairs is hashtable of artifactPath -> sha256:<hex>.
function Write-Pins([string]$ManifestPath, [hashtable]$Pairs) {
  if ($null -eq $Pairs -or $Pairs.Count -eq 0) { return }
  if ($DryRun) {
    Log "[dry-run] pins update -> $ManifestPath"
    return
  }
  $data = @{}
  if (Test-Path $ManifestPath) {
    $data = Read-JsonAsHashtable $ManifestPath
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

# Read prior lastAppliedVersion from manifest. Returns "" when missing/unreadable.
function Read-PriorVersion([string]$ManifestPath) {
  if (-not (Test-Path $ManifestPath)) { return "" }
  $data = Read-JsonAsHashtable $ManifestPath
  if (-not $data.ContainsKey("source") -or $null -eq $data["source"]) { return "" }
  if (-not $data["source"].ContainsKey("lastAppliedVersion")) { return "" }
  return [string]$data["source"]["lastAppliedVersion"]
}

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
  # Auto-detect branch from RUBBER_DUCK_SOURCE_URL if not explicitly set
  if ($Branch -eq "main" -and -not [string]::IsNullOrWhiteSpace($env:RUBBER_DUCK_SOURCE_URL)) {
    $m = [regex]::Match($env:RUBBER_DUCK_SOURCE_URL, 'githubusercontent\.com/[^/]+/[^/]+/([^/]+)/')
    if ($m.Success) {
      $detected = $m.Groups[1].Value
      if (-not [string]::IsNullOrWhiteSpace($detected) -and $detected -ne "main") {
        $Branch = $detected
        Write-Host "Auto-detected branch: $Branch"
      }
    }
  }
  # Default RawBase from branch if not explicitly set
  if ([string]::IsNullOrWhiteSpace($RawBase)) {
    $RawBase = "https://raw.githubusercontent.com/sprngr/rubber-duck/$Branch"
  }
  if ($Branch -ne "main") {
    Write-Host "Using branch: $Branch"
  }
  if ($Action -eq "sync") {
    $ManifestPath = Get-ManifestPath
    if (-not (Test-Path $ManifestPath)) {
      throw "Manifest missing: $ManifestPath. Run install first."
    }
    if ([string]::IsNullOrWhiteSpace((Get-SyncScriptPath))) {
      throw "sync requires file-backed execution (not piped)."
    }
    if (-not (Test-RawBaseAllowed $RawBase (Get-RawBaseCheckMode))) {
      throw "rawBase not in allowlist: $RawBase. Use -AllowUntrustedSource to override."
    }
    $manifest = Read-JsonAsHashtable $ManifestPath
    if ($null -eq $manifest) { $manifest = @{} }
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

    $syncGroups = @{}
    $syncGroupOrder = @()
    foreach ($t in $syncTargets) {
      $cfg = if ($manifest.ContainsKey("targets") -and $manifest["targets"].ContainsKey($t)) { $manifest["targets"][$t] } else { @{} }
      $tInstallSkills = if ($cfg.ContainsKey("installSkills")) { [bool]$cfg["installSkills"] } else { $true }
      $tInstallAgentsMd = if ($cfg.ContainsKey("installAgentsMd")) { [bool]$cfg["installAgentsMd"] } else { $true }
      $tExtras = if ($cfg.ContainsKey("extras")) { [bool]$cfg["extras"] } else { $false }
      $tSessionHook = if ($cfg.ContainsKey("sessionHook")) { [bool]$cfg["sessionHook"] } else { $false }
      $groupKey = "$tInstallSkills|$tInstallAgentsMd|$tExtras|$tSessionHook"
      if (-not $syncGroups.ContainsKey($groupKey)) {
        $syncGroups[$groupKey] = [System.Collections.Generic.List[string]]::new()
        $syncGroupOrder += $groupKey
      }
      $syncGroups[$groupKey].Add($t)
    }

    # Detect current PowerShell host for sync replay re-invocation.
    # NOTE: Mirrored in src/install/scripts/sync-latest.ps1.tmpl.
    # If you change one, update the other.
    $psExe = $null
    try { $psExe = (Get-Process -Id $PID).Path } catch { }
    if ([string]::IsNullOrWhiteSpace($psExe)) {
      $psExe = "pwsh"
      try { Get-Command pwsh -ErrorAction Stop | Out-Null } catch { $psExe = "powershell" }
    }

    foreach ($groupKey in $syncGroupOrder) {
      $parts = $groupKey -split '\|', 4
      $gInstallSkills = [bool]::Parse($parts[0])
      $gInstallAgentsMd = [bool]::Parse($parts[1])
      $gExtras = [bool]::Parse($parts[2])
      $gSessionHook = [bool]::Parse($parts[3])
      $groupHarness = ($syncGroups[$groupKey] -join ",")

      $syncArgs = Get-SyncReplayArgs "install" $groupHarness -SkipSkills:(-not $gInstallSkills) -Extras:$gExtras -SessionHook:$gSessionHook
      & $psExe @syncArgs
      if ($LASTEXITCODE -ne 0) { throw "sync install failed for harness group: $groupHarness" }
    }
    if ($Prune) {
      foreach ($t in @("opencode","copilot","claude")) {
        if (-not $syncTargetSet.ContainsKey($t)) {
          $syncArgs = Get-SyncReplayArgs "uninstall" $t
          & $psExe @syncArgs
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

# When run via `iwr | iex` there is no backing script file path.
# In function scope, $MyInvocation.MyCommand.Path can also be empty even for file execution.
# Use script path variables first, then classify piped mode only if still empty.
$ScriptPath = $PSCommandPath
if ([string]::IsNullOrWhiteSpace($ScriptPath)) {
  $ScriptPath = $MyInvocation.PSCommandPath
}
if ([string]::IsNullOrWhiteSpace($ScriptPath)) {
  $ScriptPath = $MyInvocation.MyCommand.Path
}
$script:RunningPiped = [string]::IsNullOrWhiteSpace($ScriptPath)
if ($script:RunningPiped) {
  $ScriptDir = [System.IO.Path]::GetTempPath()
  $RepoRoot = [System.IO.Path]::GetTempPath()
} else {
  $ScriptDir = Split-Path -Parent $ScriptPath
  if ([string]::IsNullOrWhiteSpace($ScriptDir)) { $ScriptDir = (Get-Location).Path }
  $RepoRoot = Split-Path -Parent $ScriptDir
  if ([string]::IsNullOrWhiteSpace($RepoRoot)) { $RepoRoot = $ScriptDir }
}
$script:LocalAgentsDir = $null
$script:RemoteAgentsPath = $null
$script:PolicyMode = "managed_block"  # managed_block|file
$script:CanonicalVersion = "unknown"

$ManagedStart = "<!-- RUBBER_DUCK_MANAGED_BLOCK START -->"
$ManagedEnd = "<!-- RUBBER_DUCK_MANAGED_BLOCK END -->"
$script:SyncWrapperTemplateRemotePath = "dist/scripts/sync-latest.ps1"
$script:SyncWrapperWritten = $false

# Built agent filenames are identical across harnesses (<name>.md)
$AgentFiles = @(
  "rubber-duck.md",
  "duckling.md"
)

# Session-start hook artifacts (opencode), sourced from dist/opencode/hooks.
$SessionHookFiles = @(
  "session-start.opencode.plugin.js",
  "session-start.directive.md"
)
$script:RemoteSessionHooksPath = "dist/opencode/hooks"
$script:LocalSessionHooksDir = $null

# Claude session-start hook artifacts, sourced from dist/claude/hooks.
$ClaudeHookFiles = @(
  "session-start.sh",
  "session-start.ps1",
  "claude-code.session-start.hooks.json",
  "claude-code.session-start.hooks.windows.json"
)
$script:RemoteClaudeHooksPath = "dist/claude/hooks"
$script:LocalClaudeHooksDir = $null

function Get-AgentRemotePinKey([string]$DestFile) {
  return "$($script:RemoteAgentsPath)/$DestFile"
}

$DefaultSkills = @(
  "duck-debt",
  "duck-debug",
  "duck-design",
  "duck-patch",
  "duck-policy",
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
  "duck-tape",
  "duck-tidy"
)

# Ensure directory exists; in dry-run mode warn without creating.
function Ensure-Dir([string]$Path, [string]$Label) {
  if ([string]::IsNullOrWhiteSpace($Path)) { return }
  if ($DryRun) {
    if (-not (Test-Path $Path)) { Warn "doctor: $Label missing, would create: $Path" }
  } else {
    New-Item -ItemType Directory -Force -Path $Path | Out-Null
  }
}

# Read a plain VERSION file (content like "v3.0.0"), trimmed. Returns $null if missing or malformed.
function Get-PlainVersion([string]$Path) {
  if (-not (Test-Path $Path)) { return $null }
  $content = (Get-Content -Raw $Path).Trim()
  if ($content -match '^(v[0-9]+\.[0-9]+\.[0-9]+)$') { return $content }
  return $null
}

function Resolve-Target {
  if ($OpenCode) {
    $script:Target = "opencode"
    if ($Project) {
      $script:DestAgentsDir = ".opencode/agents"
      $script:DestPolicyMd = "AGENTS.md"
      $script:DestPluginsDir = ".opencode/plugins"
    } else {
      $script:DestAgentsDir = Join-Path $HOME ".config/opencode/agents"
      $script:DestPolicyMd = Join-Path $HOME ".config/opencode/AGENTS.md"
      $script:DestPluginsDir = Join-Path $HOME ".config/opencode/plugins"
    }
    $script:PolicyMode = "managed_block"
    if (Test-Path (Join-Path $RepoRoot "dist/opencode/agents")) {
      $script:LocalAgentsDir = Join-Path $RepoRoot "dist/opencode/agents"
    } else {
      $script:LocalAgentsDir = Join-Path $RepoRoot "agents"
    }
    $script:RemoteAgentsPath = "dist/opencode/agents"
    $script:LocalSessionHooksDir = Join-Path $RepoRoot "dist/opencode/hooks"
    return
  }

  if ($Claude) {
    $script:Target = "claude"
    if ($Project) {
      $script:DestAgentsDir = ".claude/agents"
      $script:DestPolicyMd = "CLAUDE.md"
      $script:DestClaudeSettings = ".claude/settings.local.json"
      $script:DestClaudeHooksDir = ".claude/hooks"
    } else {
      $script:DestAgentsDir = Join-Path $HOME ".claude/agents"
      $script:DestPolicyMd = Join-Path $HOME ".claude/CLAUDE.md"
      $script:DestClaudeSettings = Join-Path $HOME ".claude/settings.local.json"
      $script:DestClaudeHooksDir = Join-Path $HOME ".claude/hooks"
    }
    $policyParent = Split-Path -Parent $script:DestPolicyMd
    if ([string]::IsNullOrWhiteSpace($policyParent)) { $policyParent = "." }
    $script:DestClaudeAgentsMd = Join-Path $policyParent "AGENTS.md"
    $script:PolicyMode = "file"
    $script:LocalAgentsDir = Join-Path $RepoRoot "dist/claude/agents"
    $script:RemoteAgentsPath = "dist/claude/agents"
    $script:LocalClaudeHooksDir = Join-Path $RepoRoot "dist/claude/hooks"
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
    if (Test-Path (Join-Path $RepoRoot "dist/copilot/agents")) {
      $script:LocalAgentsDir = Join-Path $RepoRoot "dist/copilot/agents"
    } else {
      $script:LocalAgentsDir = Join-Path $RepoRoot "agents"
    }
    $script:RemoteAgentsPath = "dist/copilot/agents"
    return
  }

  throw "Internal error: target resolution reached fallback unexpectedly."
}

function Has-LocalSources {
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
    foreach ($f in $AgentFiles) {
      Copy-Item -Force (Join-Path $script:LocalAgentsDir $f) (Join-Path $script:TmpDir $f)
    }
    if ($SessionHook -and $script:Target -eq "opencode") {
      New-Item -ItemType Directory -Force -Path (Join-Path $script:TmpDir "hooks") | Out-Null
      foreach ($hf in $SessionHookFiles) {
        Copy-Item -Force (Join-Path $script:LocalSessionHooksDir $hf) (Join-Path $script:TmpDir "hooks" $hf)
      }
    }
    if ($SessionHook -and $script:Target -eq "claude") {
      New-Item -ItemType Directory -Force -Path (Join-Path $script:TmpDir "claude-hooks") | Out-Null
      foreach ($hf in $ClaudeHookFiles) {
        Copy-Item -Force (Join-Path $script:LocalClaudeHooksDir $hf) (Join-Path $script:TmpDir "claude-hooks" $hf)
      }
    }
    return
  }

  foreach ($f in $AgentFiles) {
    Invoke-WebRequest -UseBasicParsing -Uri "$RawBase/$($script:RemoteAgentsPath)/$f" -OutFile (Join-Path $script:TmpDir $f)
  }
  if ($SessionHook -and $script:Target -eq "opencode") {
    New-Item -ItemType Directory -Force -Path (Join-Path $script:TmpDir "hooks") | Out-Null
    foreach ($hf in $SessionHookFiles) {
      Invoke-WebRequest -UseBasicParsing -Uri "$RawBase/$($script:RemoteSessionHooksPath)/$hf" -OutFile (Join-Path $script:TmpDir "hooks" $hf)
    }
  }
  if ($SessionHook -and $script:Target -eq "claude") {
    New-Item -ItemType Directory -Force -Path (Join-Path $script:TmpDir "claude-hooks") | Out-Null
    foreach ($hf in $ClaudeHookFiles) {
      Invoke-WebRequest -UseBasicParsing -Uri "$RawBase/$($script:RemoteClaudeHooksPath)/$hf" -OutFile (Join-Path $script:TmpDir "claude-hooks" $hf)
    }
  }
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

function Test-ManagedBlock([string]$Target) {
  if (-not (Test-Path $Target)) { return $false }
  $current = Get-Content -Raw $Target
  return ($current -match [regex]::Escape($ManagedStart)) -and ($current -match [regex]::Escape($ManagedEnd))
}

function Remove-ManagedBlock([string]$Target) {
  if ($DryRun) { Log "[dry-run] remove managed block from $Target"; return }
  if (-not (Test-Path $Target)) { return }
  $current = Get-Content -Raw $Target
  if ($current -match [regex]::Escape($ManagedStart)) {
    Log "Removing managed block from $Target (3.x migration)"
    $stripped = Strip-ManagedBlockText $current
    Set-Content -Path $Target -Value $stripped
  }
}

# Handle legacy managed-block migration for the resolved target.
# When -Notify (install), emit a prominent notice before touching files.
# Only strips files that actually contain the legacy block.
function Strip-LegacyPolicyBlocks {
  param([switch]$Notify)
  $targets = @($DestPolicyMd)
  if ($PolicyMode -ne "managed_block") {
    $targets += $DestClaudeAgentsMd
  }
  $any = $false
  foreach ($t in $targets) {
    if (Test-ManagedBlock $t) { $any = $true }
  }
  if (-not $any) { return }
  if ($Notify) {
    Log ""
    Log "!! Legacy managed policy block detected (3.x migration)"
    Log "   Policy now loads via the duck-policy skill; the block will be removed."
  }
  foreach ($t in $targets) {
    if (Test-ManagedBlock $t) {
      Remove-ManagedBlock $t
    }
  }
}

function Get-SyncWrapperPath {
  if ($Project) { return ".rubber-duck/sync-latest.ps1" }
  return (Join-Path $HOME ".config/rubber-duck/sync-latest.ps1")
}

function Install-SyncWrapper {
  $target = Get-SyncWrapperPath
  $scopeArg = if ($Project) { "-Project" } else { "-Global" }
  if ($script:EffectiveSource -eq "local") {
    $installerUrl = $ScriptPath
  } else {
    $installerUrl = "$RawBase/scripts/rubber-duck.ps1"
  }

  if ($DryRun) {
    Log "[dry-run] write sync helper -> $target"
    return
  }

  $parent = Split-Path -Parent $target
  if (-not [string]::IsNullOrWhiteSpace($parent)) {
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
  }

  $content = ""
  if ($script:EffectiveSource -eq "local") {
    $templatePath = Join-Path $RepoRoot "dist/scripts/sync-latest.ps1"
    if (-not (Test-Path $templatePath)) {
      throw "missing sync wrapper template: $templatePath. Run make build-harness."
    }
    $content = Get-Content -Raw $templatePath
  } else {
    $tmpTpl = Join-Path ([System.IO.Path]::GetTempPath()) ("rubber-duck-sync-template-" + [Guid]::NewGuid().ToString() + ".ps1")
    try {
      Invoke-WebRequest -UseBasicParsing -Uri "$RawBase/$($script:SyncWrapperTemplateRemotePath)" -OutFile $tmpTpl
      $content = Get-Content -Raw $tmpTpl
    } finally {
      if (Test-Path $tmpTpl) { Remove-Item -Force $tmpTpl }
    }
  }
  $content = $content.Replace("{{SYNC_SCOPE_ARG}}", $scopeArg)
  $content = $content.Replace("{{SYNC_INSTALLER_URL}}", $installerUrl)
  Set-Content -Path $target -Value $content
  Log "Installed sync helper -> $target"
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
  $installed = 0
  $skipped = 0
  foreach ($f in $AgentFiles) {
    $dest = Join-Path $DestAgentsDir $f
    $tmp = Join-Path $script:TmpDir $f
    if ((Test-Path $dest) -and ((Get-Sha256 $tmp) -eq (Get-Sha256 $dest))) {
      $skipped++
      continue
    }
    Copy-Item -Force $tmp $dest
    $installed++
  }
  Log "Installed $installed agents ($skipped unchanged) -> $DestAgentsDir"
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

function Install-SessionHookOpenCode {
  $destPlugin = Join-Path $script:DestPluginsDir "session-start.js"
  $destDirective = Join-Path (Split-Path -Parent $script:DestPluginsDir) "session-start.directive.md"
  if ($DryRun) {
    Log "[dry-run] session-hook: $(Join-Path $script:TmpDir 'hooks' 'session-start.opencode.plugin.js') -> $destPlugin"
    Log "[dry-run] session-hook: $(Join-Path $script:TmpDir 'hooks' 'session-start.directive.md') -> $destDirective"
    return
  }
  New-Item -ItemType Directory -Force -Path $script:DestPluginsDir, (Split-Path -Parent $destDirective) | Out-Null
  Copy-Item -Force (Join-Path $script:TmpDir "hooks" "session-start.opencode.plugin.js") $destPlugin
  Copy-Item -Force (Join-Path $script:TmpDir "hooks" "session-start.directive.md") $destDirective
  Log "Installed session-start hook -> $($script:DestPluginsDir)"
}

function Uninstall-SessionHookOpenCode {
  $destPlugin = Join-Path $script:DestPluginsDir "session-start.js"
  $destDirective = Join-Path (Split-Path -Parent $script:DestPluginsDir) "session-start.directive.md"
  if ($DryRun) {
    Log "[dry-run] session-hook rm $destPlugin $destDirective"
    return
  }
  if (Test-Path $destPlugin) { Remove-Item -Force $destPlugin }
  if (Test-Path $destDirective) { Remove-Item -Force $destDirective }
  Log "Removed session-start hook from $($script:DestPluginsDir)"
}

function Merge-ClaudeHookSettings([string]$SourceHooks) {
  $settings = $script:DestClaudeSettings
  $hookBlock = (Get-Content -Raw $SourceHooks | ConvertFrom-Json).hooks.SessionStart
  $data = @{}
  if (Test-Path $settings) {
    $existing = Get-Content -Raw $settings | ConvertFrom-Json
    $data = Convert-ToHashtableCompat $existing
  }
  if ($null -eq $data["hooks"]) { $data["hooks"] = @{} }
  $data["hooks"]["SessionStart"] = $hookBlock
  $data | ConvertTo-Json -Depth 10 | Set-Content -NoNewline -Path $settings
}

function Install-SessionHookClaude {
  $hooksDir = $script:DestClaudeHooksDir
  if ($DryRun) {
    foreach ($hf in $ClaudeHookFiles) {
      Log "[dry-run] session-hook: $(Join-Path $script:TmpDir 'claude-hooks' $hf) -> $(Join-Path $hooksDir $hf)"
    }
    Log "[dry-run] session-hook: merge SessionStart -> $($script:DestClaudeSettings)"
    return
  }
  New-Item -ItemType Directory -Force -Path $hooksDir | Out-Null
  foreach ($hf in $ClaudeHookFiles) {
    Copy-Item -Force (Join-Path $script:TmpDir "claude-hooks" $hf) (Join-Path $hooksDir $hf)
  }
  Merge-ClaudeHookSettings (Join-Path $hooksDir "claude-code.session-start.hooks.json")
  Log "Installed session-start hook -> $hooksDir"
}

function Uninstall-SessionHookClaude {
  $hooksDir = $script:DestClaudeHooksDir
  $settings = $script:DestClaudeSettings
  if ($DryRun) {
    Log "[dry-run] session-hook rm $hooksDir/* and remove SessionStart from $settings"
    return
  }
  foreach ($hf in $ClaudeHookFiles) {
    $dest = Join-Path $hooksDir $hf
    if (Test-Path $dest) { Remove-Item -Force $dest }
  }
  if (Test-Path $settings) {
    $data = Get-Content -Raw $settings | ConvertFrom-Json
    if ($data.hooks.PSObject.Properties.Name -contains "SessionStart") {
      $data.hooks.PSObject.Properties.Remove("SessionStart")
      $data | ConvertTo-Json -Depth 10 | Set-Content -NoNewline -Path $settings
    }
  }
  Log "Removed session-start hook from $hooksDir"
}

function Skills-Install([string[]]$Agents = @()) {
  if ($SkipSkills) { return }
  $agentArgs = @()
  foreach ($a in $Agents) { $agentArgs += @("-a", $a) }
  if ($DryRun) {
    $installList = @() + $DefaultSkills
    if ($Extras) { $installList += $ExtrasSkills }
    $scope = if ($Project) { @() } else { @("-g") }
    Log "[dry-run] npx $SkillsCli add $SkillsSource --skill $($installList -join ' ') $($agentArgs -join ' ') $($scope -join ' ') -y"
    return
  }
  if (-not (Get-Command npx -ErrorAction SilentlyContinue)) {
    Warn "npx not found; skipping skills install"
    return
  }
  $installList = @() + $DefaultSkills
  if ($Extras) { $installList += $ExtrasSkills }
  $scope = if ($Project) { @() } else { @("-g") }
  $cliArgs = @("--yes", $SkillsCli, "add", $SkillsSource, "--skill") + $installList + $agentArgs + $scope
  & npx @cliArgs
}

function Skills-Uninstall([string[]]$Agents = @()) {
  if ($SkipSkills) { return }
  $agentArgs = @()
  foreach ($a in $Agents) { $agentArgs += @("-a", $a) }
  if ($DryRun) {
    $allSkills = @() + $DefaultSkills + $ExtrasSkills
    $scope = if ($Project) { @() } else { @("-g") }
    Log "[dry-run] npx $SkillsCli remove $SkillsSource --skill $($allSkills -join ' ') $($agentArgs -join ' ') $($scope -join ' ') -y"
    return
  }
  if (-not (Get-Command npx -ErrorAction SilentlyContinue)) {
    Warn "npx not found; skipping skills uninstall"
    return
  }
  $allSkills = @() + $DefaultSkills + $ExtrasSkills
  $scope = if ($Project) { @() } else { @("-g") }
  try {
    $cliArgs = @("--yes", $SkillsCli, "remove", $SkillsSource, "--skill") + $allSkills + $agentArgs + $scope
    & npx @cliArgs
  } catch {
    Warn "skills remove failed; remove package manually if needed"
  }
}

# Map our target names to skills CLI agent identifiers.
function Get-SkillsAgent([string]$Target) {
  switch ($Target) {
    "opencode" { return "opencode" }
    "copilot"  { return "github-copilot" }
    "claude"   { return "claude-code" }
    default    { return "" }
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
    $cliArgs = @("--yes", $SkillsCli, "list") + $scope
    $list = & npx @cliArgs | Out-String
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

function Status {
  Log "agents_dir: $DestAgentsDir"
  Log "version: $script:CanonicalVersion"
  $installed = 0
  foreach ($f in $AgentFiles) {
    if (Test-Path (Join-Path $DestAgentsDir $f)) { $installed++ }
  }
  Log "agents: $installed/$($AgentFiles.Count) present"
}

function Doctor {
  if ([string]::IsNullOrWhiteSpace($DestAgentsDir) -or [string]::IsNullOrWhiteSpace($DestPolicyMd) -or [string]::IsNullOrWhiteSpace($PolicyMode)) {
    throw "Doctor: call Resolve-Target before Doctor (unresolved target)"
  }
  Ensure-Dir $DestAgentsDir "agents dir"
  Ensure-Dir (Split-Path -Parent $DestPolicyMd) "policy parent"
  if ($PolicyMode -eq "file") {
    Ensure-Dir (Split-Path -Parent $DestClaudeAgentsMd) "policy parent"
  }
}

function Update-ManifestTarget([string]$Operation, [string]$TargetName) {
  if ($Action -eq "sync") { return }
  if ($DryRun) {
    $dryManifestPath = Get-ManifestPath
    Log "[dry-run] manifest $Operation $TargetName -> $dryManifestPath"
    return
  }
  $ManifestPath = Get-ManifestPath
  $priorVersion = Read-PriorVersion $ManifestPath
  Warn-OnDowngrade $priorVersion $script:CanonicalVersion
  $ManifestParent = Split-Path -Parent $ManifestPath
  if (-not [string]::IsNullOrWhiteSpace($ManifestParent)) {
    New-Item -ItemType Directory -Force -Path $ManifestParent | Out-Null
  }
  $manifest = @{}
  if (Test-Path $ManifestPath) {
    $manifest = Read-JsonAsHashtable $ManifestPath
  } else {
    $templatePath = Join-Path $RepoRoot "dist/templates/manifest.template.json"
    if (Test-Path $templatePath) {
      $manifest = Read-JsonAsHashtable $templatePath
    }
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
      installAgentsMd = $true
      installSkills = (-not $SkipSkills)
      extras = [bool]$Extras
      sessionHook = [bool]$SessionHook
    }
  } elseif ($Operation -eq "uninstall") {
    [void]$manifest["targets"].Remove($TargetName)
  }
  $manifest | ConvertTo-Json -Depth 10 | Set-Content -Path $ManifestPath
}

try {
  # Resolve source once (target-independent). Use first target for has-local detection.
  $firstTarget = $script:SelectedTargets[0]
  $OpenCode = $firstTarget -eq "opencode"
  $Copilot = $firstTarget -eq "copilot"
  $Claude = $firstTarget -eq "claude"
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
  if (-not (Test-RawBaseAllowed $RawBase (Get-RawBaseCheckMode))) {
    throw "rawBase not in allowlist: $RawBase. Use -AllowUntrustedSource to override."
  }

  # Pre-loop header (install/uninstall only)
  if ($Action -eq "install" -or $Action -eq "uninstall") {
    if ($Action -eq "install") { Print-Banner }
    Resolve-CanonicalVersion
    Log "version: $script:CanonicalVersion"
    if ($script:EffectiveSource -eq "local") {
      Log "source: local ($RepoRoot)"
    } else {
      Log "source: web ($RawBase)"
    }
    Log "doctor: ok"
  }

  # Consolidated skills call: one npx invocation with -a for each selected target.
  if ($Action -eq "install" -or $Action -eq "uninstall") {
    $skillsAgents = @()
    foreach ($t in $script:SelectedTargets) {
      $a = Get-SkillsAgent $t
      if (-not [string]::IsNullOrWhiteSpace($a)) { $skillsAgents += $a }
    }
    if ($skillsAgents.Count -gt 0) {
      if ($Action -eq "install") { Skills-Install $skillsAgents }
      else { Skills-Uninstall $skillsAgents }
      Skills-Status
    }
  }

  foreach ($SelectedTarget in $script:SelectedTargets) {
    $OpenCode = $SelectedTarget -eq "opencode"
    $Copilot = $SelectedTarget -eq "copilot"
    $Claude = $SelectedTarget -eq "claude"

    Resolve-Target
    if ($Action -eq "install" -or $Action -eq "uninstall") {
      Log ""
      Log "[$SelectedTarget]"
    }
    switch ($Action) {
      "install" {
        Doctor
        Download-Sources
        Install-Agents
        if ($SessionHook -and $script:Target -eq "opencode") {
          Install-SessionHookOpenCode
        }
        if ($SessionHook -and $script:Target -eq "claude") {
          Install-SessionHookClaude
        }
        if (-not $script:SyncWrapperWritten) {
          Install-SyncWrapper
          $script:SyncWrapperWritten = $true
        }
        Strip-LegacyPolicyBlocks -Notify
        Status
        Update-ManifestTarget "install" $script:Target
        $pinManifestPath = Get-ManifestPath
        $pinPairs = @{}
        foreach ($pinF in $AgentFiles) {
          $h = Get-Sha256 (Join-Path $script:TmpDir $pinF)
          if ($h) { $pinPairs[(Get-AgentRemotePinKey $pinF)] = $h }
        }
        if ($SessionHook -and $script:Target -eq "opencode") {
          foreach ($hf in $SessionHookFiles) {
            $h = Get-Sha256 (Join-Path $script:TmpDir "hooks" $hf)
            if ($h) { $pinPairs["$($script:RemoteSessionHooksPath)/$hf"] = $h }
          }
        }
        if ($SessionHook -and $script:Target -eq "claude") {
          foreach ($hf in $ClaudeHookFiles) {
            $h = Get-Sha256 (Join-Path $script:TmpDir "claude-hooks" $hf)
            if ($h) { $pinPairs["$($script:RemoteClaudeHooksPath)/$hf"] = $h }
          }
        }
        Write-Pins $pinManifestPath $pinPairs
      }
      "uninstall" {
        Doctor
        Download-Sources
        Uninstall-Agents
        if ($script:Target -eq "opencode") {
          Uninstall-SessionHookOpenCode
        }
        if ($script:Target -eq "claude") {
          Uninstall-SessionHookClaude
        }
        Strip-LegacyPolicyBlocks
        Status
        Update-ManifestTarget "uninstall" $script:Target
      }
      "status" { Status }
      "doctor" { Doctor }
    }
  }
  if ($Action -eq "install" -or $Action -eq "uninstall") {
    Log ""
    Log "🦆 quack"
    if ($Action -eq "install") {
      if ($Project) {
        Log "To update: pwsh .rubber-duck/sync-latest.ps1"
      } else {
        Log "To update: pwsh $(Join-Path $HOME '.config/rubber-duck/sync-latest.ps1')"
      }
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
