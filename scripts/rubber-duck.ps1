param(
  [ValidateSet("install","uninstall","status","doctor")]
  [string]$Action = "install",
  [switch]$OpenCode,
  [switch]$OpenCodeProject,
  [switch]$Copilot,
  [switch]$CopilotProject,
  [switch]$Pi,
  [switch]$PiProject,
  [switch]$Claude,
  [switch]$ClaudeProject,
  [string]$ClaudeMd,
  [switch]$SkipSkills,
  [switch]$ProjectSkills,
  [string]$SkillsSource = "https://github.com/sprngr/rubber-duck",
  [ValidateSet("auto","local","web")]
  [string]$Source = "auto",
  [string]$RawBase = "https://raw.githubusercontent.com/sprngr/rubber-duck/main"
)

function rubber-duck {
# Parameters are declared once in the top-level param() block above and read
# from script scope here (nested helper functions close over the same scope).
$ErrorActionPreference = "Stop"

# Pinned npx CLI package spec (not a flag; mirrors SKILLS_CLI in rubber-duck.sh)
$SkillsCli = "skills@^1.5.14"

if ($Claude -and $ClaudeProject) {
  throw "Cannot combine -Claude and -ClaudeProject. Choose one."
}

if ($OpenCode -and $OpenCodeProject) {
  throw "Cannot combine -OpenCode and -OpenCodeProject. Choose one."
}

if ($Pi -and $PiProject) {
  throw "Cannot combine -Pi and -PiProject. Choose one."
}

if ($Copilot -and $CopilotProject) {
  throw "Cannot combine -Copilot and -CopilotProject. Choose one."
}

if (-not $Claude -and -not $ClaudeProject -and -not [string]::IsNullOrWhiteSpace($ClaudeMd)) {
  throw "-ClaudeMd requires -Claude or -ClaudeProject."
}

# When run via `iwr | iex` there is no backing script file, so
# $MyInvocation.MyCommand.Path is null and ScriptDir/RepoRoot cannot be
# resolved. Mirror the .sh running_piped logic: flag it and force web source,
# since local artifact detection would otherwise use empty/broken paths.
# Keep ScriptDir/RepoRoot as non-null placeholders so Join-Path never throws;
# they are never used because Resolve-Source forces web when piped.
$ScriptPath = $MyInvocation.MyCommand.Path
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
$PolicyMode = "managed_block" # managed_block|file

$ManagedStart = "<!-- RUBBER_DUCK_MANAGED_BLOCK START -->"
$ManagedEnd = "<!-- RUBBER_DUCK_MANAGED_BLOCK END -->"

# Built agent filenames are identical across harnesses (<name>.md).
$AgentFiles = @(
  "rubber-duck.md",
  "duck-simple.md",
  "duck-reviewer.md",
  "duck-investigator.md",
  "duck-dry.md",
  "duck-builder.md",
  "duck-adversary.md"
)

$RequiredSkills = @(
  "duck-debt",
  "duck-debug",
  "duck-design",
  "duck-explain",
  "duck-review",
  "duck-teach",
  "duck-triage"
)

$PiRequiredTools = @("read","bash","edit","write")
$PiOptionalTools = @("grep","find","ls")
$PiStatusSupported = "supported"
$PiStatusSupportedWithNote = "supported_with_note"
$PiStatusIncompatibleMissingTools = "incompatible_missing_tools"
$PiStatusIncompatibleSubagentProbeFailed = "incompatible_subagent_probe_failed"
$PiStatusUnsupportedButCompatible = "unsupported_but_compatible"
$PiStatusUnsupportedAndIncompatible = "unsupported_and_incompatible"
$PiStatusNoCompatiblePlugin = "no_compatible_plugin"
$PiStatusEnvironmentProbeFailed = "environment_probe_failed"

function Log($msg) { Write-Host $msg }
function Warn($msg) { Write-Warning $msg }

function Is-PiTarget {
  return ($script:Target -eq "pi" -or $script:Target -eq "pi-project")
}

function Join-Csv([string[]]$Items) {
  if (-not $Items -or $Items.Count -eq 0) { return "" }
  return [string]::Join(",", $Items)
}

function Pi-CleanToken([string]$Token) {
  if ([string]::IsNullOrWhiteSpace($Token)) { return "" }
  return ($Token -replace '[,;()\[\]"'']', '')
}

function Pi-ExtractPluginVersionFromList([string]$PiList, [string]$PluginId) {
  if ([string]::IsNullOrWhiteSpace($PiList) -or [string]::IsNullOrWhiteSpace($PluginId)) { return "unknown" }
  $tokens = $PiList -split '\s+'
  foreach ($raw in $tokens) {
    $token = Pi-CleanToken $raw
    if ($token.StartsWith("$PluginId@", [System.StringComparison]::Ordinal)) {
      return $token.Substring($PluginId.Length + 1)
    }
  }
  return "unknown"
}

function Pi-DetectUnknownSubagentToken([string]$PiList) {
  if ([string]::IsNullOrWhiteSpace($PiList)) { return "" }
  $matches = [regex]::Matches($PiList, '@[A-Za-z0-9._-]+/[A-Za-z0-9._-]*subagents[A-Za-z0-9._-]*(@[0-9][^\s]*)?|[A-Za-z0-9._-]*subagents[A-Za-z0-9._-]*(@[0-9][^\s]*)?', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
  foreach ($m in $matches) {
    $v = $m.Value
    if ($v -match 'worktree|permission') { continue }
    return $v
  }
  return ""
}

function Pi-PolicyDecide(
  [string]$PluginKind,
  [bool]$SubagentsOk,
  [string]$MissingToolsCsv,
  [bool]$PermissionsDetected,
  [string]$ProbeError
) {
  if (-not [string]::IsNullOrWhiteSpace($ProbeError)) {
    return @{ status = $PiStatusEnvironmentProbeFailed; exitCode = 3 }
  }
  if ($PluginKind -eq "none") {
    return @{ status = $PiStatusNoCompatiblePlugin; exitCode = 2 }
  }
  if (-not $SubagentsOk) {
    if ($PluginKind -eq "known") {
      return @{ status = $PiStatusIncompatibleSubagentProbeFailed; exitCode = 2 }
    }
    return @{ status = $PiStatusUnsupportedAndIncompatible; exitCode = 2 }
  }
  if ($PluginKind -eq "known" -and -not [string]::IsNullOrWhiteSpace($MissingToolsCsv)) {
    return @{ status = $PiStatusIncompatibleMissingTools; exitCode = 2 }
  }
  if ($PluginKind -eq "known") {
    if ($PermissionsDetected) {
      return @{ status = $PiStatusSupported; exitCode = 0 }
    }
    return @{ status = $PiStatusSupportedWithNote; exitCode = 0 }
  }
  return @{ status = $PiStatusUnsupportedButCompatible; exitCode = 0 }
}

function Pi-PolicyMessage([string]$Status, [string]$PluginId, [string]$Version, [string]$MissingCsv, [string]$ProbeError) {
  switch ($Status) {
    $PiStatusSupported {
      return "Pi coding harness enabled (supported plugin: $PluginId@$Version)."
    }
    $PiStatusSupportedWithNote {
      return "Pi coding harness enabled (supported plugin: $PluginId@$Version). Note: permission plugin not detected; tool-governance UX may be reduced."
    }
    $PiStatusUnsupportedButCompatible {
      return "Pi coding harness enabled (plugin: $PluginId@$Version). Note: this plugin is currently unsupported by policy; capability checks passed."
    }
    $PiStatusNoCompatiblePlugin {
      return "Cannot enable Pi coding harness: no compatible subagent plugin detected. Install one of: pi-subagents, @tintinweb/pi-subagents, @gotgenes/pi-subagents."
    }
    $PiStatusIncompatibleSubagentProbeFailed {
      return "Cannot enable Pi coding harness: detected plugin $PluginId@$Version, but subagent capability probe failed."
    }
    $PiStatusIncompatibleMissingTools {
      return "Cannot enable Pi coding harness: missing required tools: $MissingCsv. Required: read, bash, edit, write."
    }
    $PiStatusUnsupportedAndIncompatible {
      return "Cannot enable Pi coding harness: detected unsupported plugin $PluginId@$Version, and compatibility probes failed."
    }
    $PiStatusEnvironmentProbeFailed {
      return "Cannot enable Pi coding harness: unable to run plugin/capability probes in this environment ($ProbeError)."
    }
    default {
      return "Cannot enable Pi coding harness: internal policy status not recognized ($Status)."
    }
  }
}

function Pi-PolicyGate {
  Log "Checking Pi compatibility..."

  $pluginKind = "none"
  $pluginId = ""
  $pluginVersion = "unknown"
  $subagentsOk = $false
  $permissionsDetected = $false
  $probeError = ""
  $toolsCsv = ""
  $missingTools = @()
  $missingOptionalTools = @()

  if (-not (Get-Command pi -ErrorAction SilentlyContinue)) {
    throw "required command missing: pi"
  }

  try {
    $piList = (& pi list 2>$null | Out-String)
  } catch {
    $piList = ""
    $probeError = "pi list failed"
  }

  if ([string]::IsNullOrWhiteSpace($probeError)) {
    if ($piList -match '@gotgenes/pi-subagents') {
      $pluginKind = "known"
      $pluginId = "@gotgenes/pi-subagents"
    } elseif ($piList -match '@tintinweb/pi-subagents') {
      $pluginKind = "known"
      $pluginId = "@tintinweb/pi-subagents"
    } elseif ($piList -match 'pi-subagents') {
      $pluginKind = "known"
      $pluginId = "pi-subagents"
    } elseif ($piList -match '(?i)subagents') {
      $pluginKind = "unknown"
      $unknown = Pi-DetectUnknownSubagentToken $piList
      if (-not [string]::IsNullOrWhiteSpace($unknown)) {
        if ($unknown -match '@[0-9]') {
          $at = $unknown.LastIndexOf('@')
          if ($at -gt 0) {
            $pluginId = $unknown.Substring(0, $at)
            $pluginVersion = $unknown.Substring($at + 1)
          } else {
            $pluginId = $unknown
          }
        } else {
          $pluginId = $unknown
        }
      } else {
        $pluginId = "unknown-subagents-plugin"
      }
    }

    if ($piList -match '(?i)pi-permission-system') {
      $permissionsDetected = $true
    }

    if (-not [string]::IsNullOrWhiteSpace($pluginId) -and $pluginVersion -eq "unknown") {
      $pluginVersion = Pi-ExtractPluginVersionFromList $piList $pluginId
    }
  }

  if ([string]::IsNullOrWhiteSpace($probeError) -and $pluginKind -ne "none") {
    $subagentProbeCmd = if ($env:PI_SUBAGENT_PROBE_CMD) { $env:PI_SUBAGENT_PROBE_CMD } else { "pi list | Select-String -Pattern 'subagent'" }
    $toolsProbeCmd = if ($env:PI_TOOLS_PROBE_CMD) { $env:PI_TOOLS_PROBE_CMD } else { "pi -p 'tools'" }

    try {
      if ($env:PI_SUBAGENT_PROBE_CMD) {
        Invoke-Expression $subagentProbeCmd *> $null
        if ($LASTEXITCODE -eq 0) { $subagentsOk = $true }
      } else {
        $subagentProbeOut = (Invoke-Expression $subagentProbeCmd 2>$null | Out-String)
        if (-not [string]::IsNullOrWhiteSpace($subagentProbeOut)) { $subagentsOk = $true }
      }
    } catch { }

    try {
      $toolsOutput = (Invoke-Expression $toolsProbeCmd 2>$null | Out-String).ToLowerInvariant()
      $present = @()
      foreach ($tool in ($PiRequiredTools + $PiOptionalTools)) {
        if ($toolsOutput -match "(^|[^a-z0-9_-])$tool([^a-z0-9_-]|$)") {
          $present += $tool
        }
      }
      $toolsCsv = Join-Csv $present
    } catch { }
  }

  if ($subagentsOk) {
    foreach ($required in $PiRequiredTools) {
      if ($toolsCsv -notmatch "(^|,)$required(,|$)") {
        $missingTools += $required
      }
    }
    foreach ($optional in $PiOptionalTools) {
      if ($toolsCsv -notmatch "(^|,)$optional(,|$)") {
        $missingOptionalTools += $optional
      }
    }
  }

  $missingCsv = Join-Csv $missingTools
  $decision = Pi-PolicyDecide $pluginKind $subagentsOk $missingCsv $permissionsDetected $probeError
  $message = Pi-PolicyMessage $decision.status $pluginId $pluginVersion $missingCsv $probeError

  if ($decision.exitCode -eq 0) {
    if ($decision.status -eq $PiStatusSupportedWithNote -or $decision.status -eq $PiStatusUnsupportedButCompatible) {
      Warn $message
    } else {
      Log $message
    }
    $missingOptionalCsv = Join-Csv $missingOptionalTools
    if (-not [string]::IsNullOrWhiteSpace($missingOptionalCsv)) {
      Warn "Optional Pi tools not available: $missingOptionalCsv. Some read-only helper behaviors may be reduced."
    }
    Log "Pi compatibility status: $($decision.status) (exit $($decision.exitCode))"
    return
  }

  Write-Error $message
  switch ($decision.status) {
    $PiStatusNoCompatiblePlugin {
      Write-Error "Next step: install one supported plugin, then retry install."
      Write-Error "Example: pi add pi-subagents"
    }
    $PiStatusIncompatibleSubagentProbeFailed {
      Write-Error "Next step: verify plugin is enabled and subagent detection works (try: pi list | Select-String -Pattern 'subagent')."
    }
    $PiStatusIncompatibleMissingTools {
      Write-Error "Next step: ensure required tools are exposed in Pi subagents plugin config (read,bash,edit,write)."
      Write-Error "Check: pi -p 'tools'"
    }
    $PiStatusUnsupportedAndIncompatible {
      Write-Error "Next step: use a supported plugin or configure your plugin to pass capability probes."
    }
    $PiStatusEnvironmentProbeFailed {
      Write-Error "Next step: verify Pi CLI works in this shell (try: pi list), then rerun install."
    }
  }
  Write-Error "Pi compatibility status: $($decision.status) (exit $($decision.exitCode))"
  exit $decision.exitCode
}

function Resolve-Target {
  if ($Pi) {
    $script:Target = "pi"
    $script:DestAgentsDir = Join-Path $HOME ".pi/agent/agents"
    $script:DestPolicyMd = Join-Path $HOME ".pi/agent/AGENTS.md"
    $script:PolicyMode = "managed_block"
    $script:LocalPolicyFile = Join-Path $RepoRoot "AGENTS.md"
    if (Test-Path (Join-Path $RepoRoot "dist/pi/agents")) {
      $script:LocalAgentsDir = Join-Path $RepoRoot "dist/pi/agents"
      $script:RemoteAgentsPath = "dist/pi/agents"
    } elseif (Test-Path (Join-Path $RepoRoot "dist/opencode/agents")) {
      $script:LocalAgentsDir = Join-Path $RepoRoot "dist/opencode/agents"
      $script:RemoteAgentsPath = "dist/opencode/agents"
    } else {
      $script:LocalAgentsDir = Join-Path $RepoRoot "agents"
      $script:RemoteAgentsPath = "dist/opencode/agents"
    }
    $script:RemotePolicyPath = "AGENTS.md"
    return
  }

  if ($PiProject) {
    $script:Target = "pi-project"
    $script:DestAgentsDir = ".pi/agents"
    $script:DestPolicyMd = "AGENTS.md"
    $script:PolicyMode = "managed_block"
    $script:LocalPolicyFile = Join-Path $RepoRoot "AGENTS.md"
    if (Test-Path (Join-Path $RepoRoot "dist/pi/agents")) {
      $script:LocalAgentsDir = Join-Path $RepoRoot "dist/pi/agents"
      $script:RemoteAgentsPath = "dist/pi/agents"
    } elseif (Test-Path (Join-Path $RepoRoot "dist/opencode/agents")) {
      $script:LocalAgentsDir = Join-Path $RepoRoot "dist/opencode/agents"
      $script:RemoteAgentsPath = "dist/opencode/agents"
    } else {
      $script:LocalAgentsDir = Join-Path $RepoRoot "agents"
      $script:RemoteAgentsPath = "dist/opencode/agents"
    }
    $script:RemotePolicyPath = "AGENTS.md"
    return
  }

  if ($OpenCode) {
    $script:Target = "opencode"
    $script:DestAgentsDir = Join-Path $HOME ".config/opencode/agents"
    $script:DestPolicyMd = Join-Path $HOME ".config/opencode/AGENTS.md"
    $script:PolicyMode = "managed_block"
    $script:LocalPolicyFile = Join-Path $RepoRoot "AGENTS.md"
    if (Test-Path (Join-Path $RepoRoot "dist/opencode/agents")) {
      $script:LocalAgentsDir = Join-Path $RepoRoot "dist/opencode/agents"
    } else {
      $script:LocalAgentsDir = Join-Path $RepoRoot "agents"
    }
    $script:RemotePolicyPath = "AGENTS.md"
    $script:RemoteAgentsPath = "dist/opencode/agents"
    return
  }

  if ($OpenCodeProject) {
    $script:Target = "opencode-project"
    $script:DestAgentsDir = ".opencode/agents"
    $script:DestPolicyMd = "AGENTS.md"
    $script:PolicyMode = "managed_block"
    $script:LocalPolicyFile = Join-Path $RepoRoot "AGENTS.md"
    if (Test-Path (Join-Path $RepoRoot "dist/opencode/agents")) {
      $script:LocalAgentsDir = Join-Path $RepoRoot "dist/opencode/agents"
    } else {
      $script:LocalAgentsDir = Join-Path $RepoRoot "agents"
    }
    $script:RemotePolicyPath = "AGENTS.md"
    $script:RemoteAgentsPath = "dist/opencode/agents"
    return
  }

  if ($Claude) {
    $script:Target = "claude"
    $script:DestAgentsDir = Join-Path $HOME ".claude/agents"
    $script:DestPolicyMd = if ([string]::IsNullOrWhiteSpace($ClaudeMd)) { (Join-Path $HOME ".claude/CLAUDE.md") } else { $ClaudeMd }
    $script:DestClaudeAgentsMd = Join-Path (Split-Path -Parent $script:DestPolicyMd) "AGENTS.md"
    $script:PolicyMode = "file"
    $script:LocalPolicyFile = Join-Path $RepoRoot "dist/claude/CLAUDE.md"
    $script:LocalAgentsPolicyFile = Join-Path $RepoRoot "AGENTS.md"
    $script:LocalAgentsDir = Join-Path $RepoRoot "dist/claude/agents"
    $script:RemotePolicyPath = "dist/claude/CLAUDE.md"
    $script:RemoteAgentsPolicyPath = "AGENTS.md"
    $script:RemoteAgentsPath = "dist/claude/agents"
    return
  }

  if ($Copilot) {
    $script:Target = "copilot"
    $script:DestAgentsDir = Join-Path $HOME ".copilot/agents"
    $script:DestPolicyMd = Join-Path $HOME ".copilot/AGENTS.md"
    $script:PolicyMode = "managed_block"
    $script:LocalPolicyFile = Join-Path $RepoRoot "AGENTS.md"
    if (Test-Path (Join-Path $RepoRoot "dist/copilot/agents")) {
      $script:LocalAgentsDir = Join-Path $RepoRoot "dist/copilot/agents"
    } else {
      $script:LocalAgentsDir = Join-Path $RepoRoot "agents"
    }
    $script:RemotePolicyPath = "AGENTS.md"
    $script:RemoteAgentsPath = "dist/copilot/agents"
    return
  }

  if ($CopilotProject) {
    $script:Target = "copilot-project"
    $script:DestAgentsDir = ".github/agents"
    $script:DestPolicyMd = "AGENTS.md"
    $script:PolicyMode = "managed_block"
    $script:LocalPolicyFile = Join-Path $RepoRoot "AGENTS.md"
    if (Test-Path (Join-Path $RepoRoot "dist/copilot/agents")) {
      $script:LocalAgentsDir = Join-Path $RepoRoot "dist/copilot/agents"
    } else {
      $script:LocalAgentsDir = Join-Path $RepoRoot "agents"
    }
    $script:RemotePolicyPath = "AGENTS.md"
    $script:RemoteAgentsPath = "dist/copilot/agents"
    return
  }

  if ($ClaudeProject) {
    $script:Target = "claude-project"
    $script:DestAgentsDir = ".claude/agents"
    $script:DestPolicyMd = if ([string]::IsNullOrWhiteSpace($ClaudeMd)) { "CLAUDE.md" } else { $ClaudeMd }
    $script:DestClaudeAgentsMd = Join-Path (Split-Path -Parent $script:DestPolicyMd) "AGENTS.md"
    $script:PolicyMode = "file"
    $script:LocalPolicyFile = Join-Path $RepoRoot "dist/claude/CLAUDE.md"
    $script:LocalAgentsPolicyFile = Join-Path $RepoRoot "AGENTS.md"
    $script:LocalAgentsDir = Join-Path $RepoRoot "dist/claude/agents"
    $script:RemotePolicyPath = "dist/claude/CLAUDE.md"
    $script:RemoteAgentsPolicyPath = "AGENTS.md"
    $script:RemoteAgentsPath = "dist/claude/agents"
    return
  }

  $script:Target = "opencode"
  $script:DestAgentsDir = Join-Path $HOME ".config/opencode/agents"
  $script:DestPolicyMd = Join-Path $HOME ".config/opencode/AGENTS.md"
  $script:PolicyMode = "managed_block"
  $script:LocalPolicyFile = Join-Path $RepoRoot "AGENTS.md"
  if (Test-Path (Join-Path $RepoRoot "dist/opencode/agents")) {
    $script:LocalAgentsDir = Join-Path $RepoRoot "dist/opencode/agents"
  } else {
    $script:LocalAgentsDir = Join-Path $RepoRoot "agents"
  }
  $script:RemotePolicyPath = "AGENTS.md"
  $script:RemoteAgentsPath = "dist/opencode/agents"
}

function Has-LocalSources {
  if (-not (Test-Path $LocalPolicyFile)) { return $false }
  if ($PolicyMode -eq "file" -and -not (Test-Path $LocalAgentsPolicyFile)) { return $false }
  foreach ($f in $AgentFiles) {
    if (-not (Test-Path (Join-Path $LocalAgentsDir $f))) { return $false }
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
      Copy-Item -Force $LocalPolicyFile (Join-Path $script:TmpDir "AGENTS.md")
    } else {
      Copy-Item -Force $LocalPolicyFile (Join-Path $script:TmpDir "CLAUDE.md")
      Copy-Item -Force $LocalAgentsPolicyFile (Join-Path $script:TmpDir "AGENTS.md")
    }
    foreach ($f in $AgentFiles) {
      Copy-Item -Force (Join-Path $LocalAgentsDir $f) (Join-Path $script:TmpDir $f)
    }
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
  Log "Backup created: $backup"
}

function Upsert-ManagedBlock([string]$Target, [string]$ContentFile) {
  $parent = Split-Path -Parent $Target
  if (-not [string]::IsNullOrWhiteSpace($parent)) {
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
  }
  if (-not (Test-Path $Target)) { New-Item -ItemType File -Force -Path $Target | Out-Null }
  $current = if (Test-Path $Target) { Get-Content -Raw $Target } else { "" }
  $stripped = Strip-ManagedBlockText $current
  $policy = Get-Content -Raw $ContentFile
  $next = "$stripped`n$ManagedStart`n$policy`n$ManagedEnd`n"
  Set-Content -Path $Target -Value $next
}

function Remove-ManagedBlock([string]$Target) {
  if (-not (Test-Path $Target)) { return }
  $current = Get-Content -Raw $Target
  $stripped = Strip-ManagedBlockText $current
  Set-Content -Path $Target -Value $stripped
}

function Install-PolicyFile {
  # Claude targets keep a two-file layout (CLAUDE.md -> @AGENTS.md include,
  # AGENTS.md -> policy). Upsert managed blocks into both so user-authored
  # content in either file is preserved instead of clobbered.
  Upsert-ManagedBlock $DestClaudeAgentsMd (Join-Path $script:TmpDir "AGENTS.md")
  Upsert-ManagedBlock $DestPolicyMd (Join-Path $script:TmpDir "CLAUDE.md")
  Log "Installed policy block -> $DestPolicyMd"
  Log "Installed policy block -> $DestClaudeAgentsMd"
}

function Remove-PolicyFile {
  # Strip only our managed blocks; user content in these files is left intact.
  Remove-ManagedBlock $DestPolicyMd
  Remove-ManagedBlock $DestClaudeAgentsMd
  Log "Removed policy block from $DestPolicyMd"
  Log "Removed policy block from $DestClaudeAgentsMd"
}

function Install-Agents {
  New-Item -ItemType Directory -Force -Path $DestAgentsDir | Out-Null
  foreach ($f in $AgentFiles) {
    Copy-Item -Force (Join-Path $script:TmpDir $f) (Join-Path $DestAgentsDir $f)
  }
  Log "Installed $($AgentFiles.Count) agents -> $DestAgentsDir"
}

function Uninstall-Agents {
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
  if (-not (Get-Command npx -ErrorAction SilentlyContinue)) {
    Warn "npx not found; skipping skills install"
    return
  }
  $scope = if ($ProjectSkills) { @() } else { @("-g") }
  $args = @("--yes", $SkillsCli, "add", $SkillsSource, "--skill") + $RequiredSkills + $scope
  & npx @args
}

function Skills-Uninstall {
  if ($SkipSkills) { return }
  if (-not (Get-Command npx -ErrorAction SilentlyContinue)) {
    Warn "npx not found; skipping skills uninstall"
    return
  }
  $scope = if ($ProjectSkills) { @() } else { @("-g") }
  try {
    $args = @("--yes", $SkillsCli, "remove", $SkillsSource, "--skill") + $RequiredSkills + $scope
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
  $scope = if ($ProjectSkills) { @() } else { @("-g") }
  $previousNoColor = $env:NO_COLOR
  try {
    $env:NO_COLOR = "1"
    $args = @("--yes", $SkillsCli, "list") + $scope
    $list = & npx @args | Out-String
    $allPresent = $true
    foreach ($skill in $RequiredSkills) {
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
  $state = if (Has-ManagedBlock $Target) { "present" } else { "missing" }
  Log "AGENTS policy block ($(Split-Path -Leaf $Target)): $state"
}

function Status {
  Log "target: $Target"
  Log "agents_dir: $DestAgentsDir"
  Log "policy_md: $DestPolicyMd"
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
  if (Is-PiTarget) {
    if (-not (Get-Command pi -ErrorAction SilentlyContinue)) {
      throw "required command missing: pi"
    }
  }
  New-Item -ItemType Directory -Force -Path $DestAgentsDir | Out-Null
  $policyParent = Split-Path -Parent $DestPolicyMd
  if (-not [string]::IsNullOrWhiteSpace($policyParent)) {
    New-Item -ItemType Directory -Force -Path $policyParent | Out-Null
  }
  if ($PolicyMode -eq "file") {
    $agentsParent = Split-Path -Parent $DestClaudeAgentsMd
    if (-not [string]::IsNullOrWhiteSpace($agentsParent)) {
      New-Item -ItemType Directory -Force -Path $agentsParent | Out-Null
    }
  }
  Log "doctor: ok"
}

try {
  Resolve-Target
  Resolve-Source
  switch ($Action) {
    "install" {
      Doctor
      if (Is-PiTarget) {
        Pi-PolicyGate
      }
      Download-Sources
      Install-Agents
      Backup-Md $DestPolicyMd
      if ($PolicyMode -eq "managed_block") {
        Upsert-ManagedBlock $DestPolicyMd (Join-Path $script:TmpDir "AGENTS.md")
      } else {
        Backup-Md $DestClaudeAgentsMd
        Install-PolicyFile
      }
      Skills-Install
      Status
    }
    "uninstall" {
      Doctor
      Download-Sources
      Uninstall-Agents
      Backup-Md $DestPolicyMd
      if ($PolicyMode -eq "managed_block") {
        Remove-ManagedBlock $DestPolicyMd
      } else {
        Backup-Md $DestClaudeAgentsMd
        Remove-PolicyFile
      }
      Skills-Uninstall
      Status
    }
    "status" { Status }
    "doctor" { Doctor }
  }
}
finally {
  Cleanup-Sources
}

}

if ($MyInvocation.InvocationName -ne '.') {
  rubber-duck
}
