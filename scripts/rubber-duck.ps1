function rubber-duck {
param(
  [ValidateSet("install","uninstall","status","doctor")]
  [string]$Action = "install",
  [switch]$OpenCode,
  [string]$AgentsDir,
  [string]$AgentsMd,
  [switch]$SkipSkills,
  [string]$SkillsSource = "https://github.com/sprngr/rubber-duck",
  [ValidateSet("auto","local","web")]
  [string]$Source = "auto",
  [string]$RawBase = "https://raw.githubusercontent.com/sprngr/rubber-duck/main"
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent $ScriptDir
$LocalAgentsDir = Join-Path $RepoRoot "agents"
$LocalPolicyFile = Join-Path $RepoRoot "AGENTS.md"

$ManagedStart = "<!-- RUBBER_DUCK_MANAGED_BLOCK START -->"
$ManagedEnd = "<!-- RUBBER_DUCK_MANAGED_BLOCK END -->"

$AgentFiles = @(
  "rubber-duck.agent.md",
  "duck-simple.agent.md",
  "duck-reviewer.agent.md",
  "duck-investigator.agent.md",
  "duck-dry.agent.md",
  "duck-builder.agent.md",
  "duck-adversary.agent.md"
)

function Log($msg) { Write-Host $msg }
function Warn($msg) { Write-Warning $msg }

function Resolve-Target {
  if ($OpenCode) {
    $script:Target = "opencode"
    $script:DestAgentsDir = Join-Path $HOME ".config/opencode/agents"
    $script:DestAgentsMd = Join-Path $HOME ".config/opencode/AGENTS.md"
    return
  }
  if ([string]::IsNullOrWhiteSpace($AgentsDir) -or [string]::IsNullOrWhiteSpace($AgentsMd)) {
    throw "Generic target requires -AgentsDir and -AgentsMd (or use -OpenCode)."
  }
  $script:Target = "generic"
  $script:DestAgentsDir = $AgentsDir
  $script:DestAgentsMd = $AgentsMd
}

function Has-LocalSources {
  if (-not (Test-Path $LocalPolicyFile)) { return $false }
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
    Copy-Item -Force $LocalPolicyFile (Join-Path $script:TmpDir "AGENTS.md")
    foreach ($f in $AgentFiles) {
      Copy-Item -Force (Join-Path $LocalAgentsDir $f) (Join-Path $script:TmpDir $f)
    }
    Log "source: local ($RepoRoot)"
    return
  }

  Invoke-WebRequest -UseBasicParsing -Uri "$RawBase/AGENTS.md" -OutFile (Join-Path $script:TmpDir "AGENTS.md")
  foreach ($f in $AgentFiles) {
    Invoke-WebRequest -UseBasicParsing -Uri "$RawBase/agents/$f" -OutFile (Join-Path $script:TmpDir $f)
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

function Backup-AgentsMd {
  $parent = Split-Path -Parent $DestAgentsMd
  New-Item -ItemType Directory -Force -Path $parent | Out-Null
  $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
  $backup = "$DestAgentsMd.bak.$stamp"
  if (Test-Path $DestAgentsMd) {
    Copy-Item -Force $DestAgentsMd $backup
  } else {
    New-Item -ItemType File -Force -Path $backup | Out-Null
  }
  Log "Backup created: $backup"
}

function Upsert-ManagedBlock {
  $parent = Split-Path -Parent $DestAgentsMd
  New-Item -ItemType Directory -Force -Path $parent | Out-Null
  if (-not (Test-Path $DestAgentsMd)) { New-Item -ItemType File -Force -Path $DestAgentsMd | Out-Null }
  $current = if (Test-Path $DestAgentsMd) { Get-Content -Raw $DestAgentsMd } else { "" }
  $stripped = Strip-ManagedBlockText $current
  $policy = Get-Content -Raw (Join-Path $script:TmpDir "AGENTS.md")
  $next = "$stripped`n$ManagedStart`n$policy`n$ManagedEnd`n"
  Set-Content -Path $DestAgentsMd -Value $next
}

function Remove-ManagedBlock {
  if (-not (Test-Path $DestAgentsMd)) { return }
  $current = Get-Content -Raw $DestAgentsMd
  $stripped = Strip-ManagedBlockText $current
  Set-Content -Path $DestAgentsMd -Value $stripped
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
  npx skills add $SkillsSource
}

function Skills-Uninstall {
  if ($SkipSkills) { return }
  if (-not (Get-Command npx -ErrorAction SilentlyContinue)) {
    Warn "npx not found; skipping skills uninstall"
    return
  }
  try {
    npx skills remove $SkillsSource
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
    $list = npx skills list | Out-String
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
  if (-not (Test-Path $DestAgentsMd)) { return $false }
  $text = Get-Content -Raw $DestAgentsMd
  return $text.Contains($ManagedStart) -and $text.Contains($ManagedEnd)
}

function Status {
  Log "target: $Target"
  Log "agents_dir: $DestAgentsDir"
  Log "agents_md: $DestAgentsMd"
  $installed = 0
  foreach ($f in $AgentFiles) {
    if (Test-Path (Join-Path $DestAgentsDir $f)) { $installed++ }
  }
  Log "agents: $installed/$($AgentFiles.Count) present"
  if (Has-ManagedBlock) { Log "AGENTS policy block: present" } else { Log "AGENTS policy block: missing" }
  Skills-Status
}

function Doctor {
  Resolve-Target
  Resolve-Source
  New-Item -ItemType Directory -Force -Path $DestAgentsDir | Out-Null
  New-Item -ItemType Directory -Force -Path (Split-Path -Parent $DestAgentsMd) | Out-Null
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
      Backup-AgentsMd
      Upsert-ManagedBlock
      Skills-Install
      Status
    }
    "uninstall" {
      Doctor
      Download-Sources
      Uninstall-Agents
      Backup-AgentsMd
      Remove-ManagedBlock
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
