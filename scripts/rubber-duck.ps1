param(
  [ValidateSet("install","uninstall","status","doctor")]
  [string]$Action = "install",
  [switch]$OpenCode,
  [switch]$Claude,
  [switch]$ClaudeProject,
  [string]$AgentsDir,
  [string]$AgentsMd,
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

function Log($msg) { Write-Host $msg }
function Warn($msg) { Write-Warning $msg }

function Resolve-Target {
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

  if ([string]::IsNullOrWhiteSpace($AgentsDir) -or [string]::IsNullOrWhiteSpace($AgentsMd)) {
    throw "Generic target requires -AgentsDir and -AgentsMd (or use -OpenCode)."
  }

  $script:Target = "generic"
  $script:DestAgentsDir = $AgentsDir
  $script:DestPolicyMd = $AgentsMd
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
  $null | npx --yes $SkillsCli add $SkillsSource -y $scope
}

function Skills-Uninstall {
  if ($SkipSkills) { return }
  if (-not (Get-Command npx -ErrorAction SilentlyContinue)) {
    Warn "npx not found; skipping skills uninstall"
    return
  }
  $scope = if ($ProjectSkills) { @() } else { @("-g") }
  try {
    $null | npx --yes $SkillsCli remove $SkillsSource $scope
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
  try {
    $list = $null | npx --yes $SkillsCli list $scope | Out-String
    if ($list -match [regex]::Escape($SkillsSource)) {
      Log "skills: installed ($SkillsSource)"
    } else {
      Log "skills: not detected ($SkillsSource)"
    }
  } catch {
    Log "skills: unable to query (npx skills list failed)"
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
