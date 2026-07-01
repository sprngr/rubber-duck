function rubber-duck {
param(
  [ValidateSet("install","uninstall","status","doctor")]
  [string]$Action = "install",
  [switch]$OpenCode,
  [switch]$Claude,
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

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent $ScriptDir
$LocalAgentsDir = $null
$LocalPolicyFile = $null
$LocalAgentsPolicyFile = $null
$RemoteAgentsPath = $null
$RemotePolicyPath = $null
$RemoteAgentsPolicyPath = $null
$PolicyMode = "managed_block" # managed_block|file

$ManagedStart = "<!-- RUBBER_DUCK_MANAGED_BLOCK START -->"
$ManagedEnd = "<!-- RUBBER_DUCK_MANAGED_BLOCK END -->"

$OpenCodeAgentFiles = @(
  "rubber-duck.agent.md",
  "duck-simple.agent.md",
  "duck-reviewer.agent.md",
  "duck-investigator.agent.md",
  "duck-dry.agent.md",
  "duck-builder.agent.md",
  "duck-adversary.agent.md"
)

$ClaudeAgentFiles = @(
  "rubber-duck.md",
  "duck-simple.md",
  "duck-reviewer.md",
  "duck-investigator.md",
  "duck-dry.md",
  "duck-builder.md",
  "duck-adversary.md"
)

$AgentFiles = @()

function Log($msg) { Write-Host $msg }
function Warn($msg) { Write-Warning $msg }

function Resolve-Target {
  if ($OpenCode) {
    $script:Target = "opencode"
    $script:DestAgentsDir = Join-Path $HOME ".config/opencode/agents"
    $script:DestPolicyMd = Join-Path $HOME ".config/opencode/AGENTS.md"
    $script:PolicyMode = "managed_block"
    $script:AgentFiles = $OpenCodeAgentFiles
    if (Test-Path (Join-Path $RepoRoot "dist/opencode/AGENTS.md")) {
      $script:LocalPolicyFile = Join-Path $RepoRoot "dist/opencode/AGENTS.md"
      $script:LocalAgentsDir = Join-Path $RepoRoot "dist/opencode/agents"
    } else {
      $script:LocalPolicyFile = Join-Path $RepoRoot "AGENTS.md"
      $script:LocalAgentsDir = Join-Path $RepoRoot "agents"
    }
    $script:RemotePolicyPath = "dist/opencode/AGENTS.md"
    $script:RemoteAgentsPath = "dist/opencode/agents"
    return
  }

  if ($Claude) {
    $script:Target = "claude"
    $script:DestAgentsDir = ".claude/agents"
    $script:DestPolicyMd = if ([string]::IsNullOrWhiteSpace($ClaudeMd)) { "CLAUDE.md" } else { $ClaudeMd }
    $script:DestClaudeAgentsMd = Join-Path (Split-Path -Parent $script:DestPolicyMd) "AGENTS.md"
    $script:PolicyMode = "file"
    $script:AgentFiles = $ClaudeAgentFiles
    $script:LocalPolicyFile = Join-Path $RepoRoot "dist/claude/CLAUDE.md"
    $script:LocalAgentsPolicyFile = Join-Path $RepoRoot "dist/opencode/AGENTS.md"
    $script:LocalAgentsDir = Join-Path $RepoRoot "dist/claude/agents"
    $script:RemotePolicyPath = "dist/claude/CLAUDE.md"
    $script:RemoteAgentsPolicyPath = "dist/opencode/AGENTS.md"
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
  $script:AgentFiles = $OpenCodeAgentFiles
  if (Test-Path (Join-Path $RepoRoot "dist/opencode/AGENTS.md")) {
    $script:LocalPolicyFile = Join-Path $RepoRoot "dist/opencode/AGENTS.md"
    $script:LocalAgentsDir = Join-Path $RepoRoot "dist/opencode/agents"
  } else {
    $script:LocalPolicyFile = Join-Path $RepoRoot "AGENTS.md"
    $script:LocalAgentsDir = Join-Path $RepoRoot "agents"
  }
  $script:RemotePolicyPath = "dist/opencode/AGENTS.md"
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
    "local" { $script:EffectiveSource = "local" }
    "web" { $script:EffectiveSource = "web" }
    "auto" {
      if (Has-LocalSources) { $script:EffectiveSource = "local" } else { $script:EffectiveSource = "web" }
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

function Backup-PolicyMd {
  $parent = Split-Path -Parent $DestPolicyMd
  New-Item -ItemType Directory -Force -Path $parent | Out-Null
  $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
  $backup = "$DestPolicyMd.bak.$stamp"
  if (Test-Path $DestPolicyMd) {
    Copy-Item -Force $DestPolicyMd $backup
  } else {
    New-Item -ItemType File -Force -Path $backup | Out-Null
  }
  Log "Backup created: $backup"
}

function Backup-ClaudeAgentsMd {
  $parent = Split-Path -Parent $DestClaudeAgentsMd
  if (-not [string]::IsNullOrWhiteSpace($parent)) {
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
  }
  $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
  $backup = "$DestClaudeAgentsMd.bak.$stamp"
  if (Test-Path $DestClaudeAgentsMd) {
    Copy-Item -Force $DestClaudeAgentsMd $backup
  } else {
    New-Item -ItemType File -Force -Path $backup | Out-Null
  }
  Log "Backup created: $backup"
}

function Upsert-ManagedBlock {
  $parent = Split-Path -Parent $DestPolicyMd
  New-Item -ItemType Directory -Force -Path $parent | Out-Null
  if (-not (Test-Path $DestPolicyMd)) { New-Item -ItemType File -Force -Path $DestPolicyMd | Out-Null }
  $current = if (Test-Path $DestPolicyMd) { Get-Content -Raw $DestPolicyMd } else { "" }
  $stripped = Strip-ManagedBlockText $current
  $policy = Get-Content -Raw (Join-Path $script:TmpDir "AGENTS.md")
  $next = "$stripped`n$ManagedStart`n$policy`n$ManagedEnd`n"
  Set-Content -Path $DestPolicyMd -Value $next
}

function Remove-ManagedBlock {
  if (-not (Test-Path $DestPolicyMd)) { return }
  $current = Get-Content -Raw $DestPolicyMd
  $stripped = Strip-ManagedBlockText $current
  Set-Content -Path $DestPolicyMd -Value $stripped
}

function Install-PolicyFile {
  $parent = Split-Path -Parent $DestPolicyMd
  if (-not [string]::IsNullOrWhiteSpace($parent)) {
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
  }
  Copy-Item -Force (Join-Path $script:TmpDir "CLAUDE.md") $DestPolicyMd
  Copy-Item -Force (Join-Path $script:TmpDir "AGENTS.md") $DestClaudeAgentsMd
  Log "Installed policy file -> $DestPolicyMd"
  Log "Installed policy file -> $DestClaudeAgentsMd"
}

function Remove-PolicyFile {
  if (-not (Test-Path $DestPolicyMd)) { return }
  $installed = Join-Path $script:TmpDir "CLAUDE.md"
  if ((Get-FileHash $DestPolicyMd).Hash -eq (Get-FileHash $installed).Hash) {
    Remove-Item -Force $DestPolicyMd
    Log "Removed policy file $DestPolicyMd"
  } else {
    Warn "policy file differs from installed artifact; leaving in place: $DestPolicyMd"
  }

  if (Test-Path $DestClaudeAgentsMd) {
    $installedAgents = Join-Path $script:TmpDir "AGENTS.md"
    if ((Get-FileHash $DestClaudeAgentsMd).Hash -eq (Get-FileHash $installedAgents).Hash) {
      Remove-Item -Force $DestClaudeAgentsMd
      Log "Removed policy file $DestClaudeAgentsMd"
    } else {
      Warn "policy file differs from installed artifact; leaving in place: $DestClaudeAgentsMd"
    }
  }
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
  if ($ProjectSkills) {
    npx skills add $SkillsSource -y
  } else {
    npx skills add $SkillsSource -y -g
  }
}

function Skills-Uninstall {
  if ($SkipSkills) { return }
  if (-not (Get-Command npx -ErrorAction SilentlyContinue)) {
    Warn "npx not found; skipping skills uninstall"
    return
  }
  try {
    if ($ProjectSkills) {
      npx skills remove $SkillsSource
    } else {
      npx skills remove $SkillsSource -g
    }
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
  try {
    if ($ProjectSkills) {
      $list = npx skills list | Out-String
    } else {
      $list = npx skills list -g | Out-String
    }
    if ($list -match [regex]::Escape($SkillsSource)) {
      Log "skills: installed ($SkillsSource)"
    } else {
      Log "skills: not detected ($SkillsSource)"
    }
  } catch {
    Log "skills: unable to query (npx skills list failed)"
  }
}

function Has-ManagedBlock {
  if (-not (Test-Path $DestPolicyMd)) { return $false }
  $text = Get-Content -Raw $DestPolicyMd
  return $text.Contains($ManagedStart) -and $text.Contains($ManagedEnd)
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
  if ($PolicyMode -eq "managed_block") {
    if (Has-ManagedBlock) { Log "AGENTS policy block: present" } else { Log "AGENTS policy block: missing" }
  } else {
    if (Test-Path $DestPolicyMd) { Log "CLAUDE.md: present" } else { Log "CLAUDE.md: missing" }
    if (Test-Path $DestClaudeAgentsMd) { Log "AGENTS.md: present" } else { Log "AGENTS.md: missing" }
  }
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
      Backup-PolicyMd
      if ($PolicyMode -eq "managed_block") {
        Upsert-ManagedBlock
      } else {
        Backup-ClaudeAgentsMd
        Install-PolicyFile
      }
      Skills-Install
      Status
    }
    "uninstall" {
      Doctor
      Download-Sources
      Uninstall-Agents
      Backup-PolicyMd
      if ($PolicyMode -eq "managed_block") {
        Remove-ManagedBlock
      } else {
        Backup-ClaudeAgentsMd
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
  rubber-duck @PSBoundParameters
}
