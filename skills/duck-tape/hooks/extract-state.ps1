# duck-tape pre-compact transcript parser (Angle A: auto-checkpoint) - PowerShell
# Windows variant of extract-state.sh. Parses session transcript and writes
# a real Agent State file. Supports Claude Code and Copilot JSONL transcripts.
# Falls back to marker-only write when transcript missing, format unknown,
# or nothing extracted. Marker format matches pre-compact.ps1.
[CmdletBinding()]
param(
  [string]$Transcript = "",
  [string]$DuckTapeDir = (Join-Path (Get-Location) ".duck-tape")
)

$ErrorActionPreference = "Stop"
$MaxBytes = if ($env:DUCK_TAPE_MAX_TRANSCRIPT_BYTES) { [long]$env:DUCK_TAPE_MAX_TRANSCRIPT_BYTES } else { 5242880L } # 5MB
$TrustedRoot = if ($env:DUCK_TAPE_TRUSTED_ROOT) { $env:DUCK_TAPE_TRUSTED_ROOT } else { "" }

# Resolve transcript from stdin JSON if $Transcript empty and stdin piped.
if ([string]::IsNullOrEmpty($Transcript) -and -not [Console]::IsInputRedirected) {
  # stdin not redirected; skip
}
elseif ([string]::IsNullOrEmpty($Transcript)) {
  try {
    $stdinText = [Console]::In.ReadToEnd()
    if ($stdinText) {
      $stdinJson = $stdinText | ConvertFrom-Json -ErrorAction Stop
      if ($stdinJson.transcript_path) { $Transcript = $stdinJson.transcript_path }
      elseif ($stdinJson.transcriptPath) { $Transcript = $stdinJson.transcriptPath }
    }
  }
  catch { # ignore stdin parse errors
  }
}

New-Item -ItemType Directory -Force -Path $DuckTapeDir | Out-Null

# .gitignore if missing
$gitignore = Join-Path $DuckTapeDir ".gitignore"
if (-not (Test-Path $gitignore)) {
  Set-Content -Path $gitignore -Value "*`n" -NoNewline
}

$timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
$stamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd-HHmm")
$cwd = (Get-Location).Path
$stateFile = Join-Path $DuckTapeDir "${stamp}-auto.state.md"
$marker = Join-Path $DuckTapeDir ".last-compact"

function Write-MarkerOnly {
  $latestState = $null
  $stateFiles = Get-ChildItem -Path $DuckTapeDir -Filter "*.state.md" -File -ErrorAction SilentlyContinue
  if ($stateFiles) {
    $latestState = ($stateFiles | Sort-Object LastWriteTime -Descending | Select-Object -First 1).Name
  }
  $line = "$timestamp | cwd: $cwd"
  if ($latestState) { $line += " | latest-state: $latestState" }
  if ($Transcript -and (Test-Path $Transcript -PathType Leaf)) { $line += " | transcript: $Transcript" }
  Set-Content -Path $marker -Value $line -NoNewline
  Write-Output $marker
}

# Require a readable transcript.
if ([string]::IsNullOrEmpty($Transcript) -or -not (Test-Path $Transcript -PathType Leaf)) {
  Write-MarkerOnly
  exit 0
}

# Trust-boundary checks: canonical path under trusted root, no symlink, size cap.
try {
  $transcriptItem = Get-Item -LiteralPath $Transcript -Force
  if ($transcriptItem.Attributes -band [IO.FileAttributes]::ReparsePoint) {
    Write-MarkerOnly
    exit 0
  }
  $transcriptReal = [System.IO.Path]::GetFullPath($transcriptItem.FullName)
  if (-not [string]::IsNullOrEmpty($TrustedRoot)) {
    $trustedReal = [System.IO.Path]::GetFullPath($TrustedRoot)
    $sep = [System.IO.Path]::DirectorySeparatorChar
    $trustedPrefix = if ($trustedReal.EndsWith($sep)) { $trustedReal } else { "$trustedReal$sep" }
    if (-not ($transcriptReal.Equals($trustedReal, [System.StringComparison]::OrdinalIgnoreCase) -or
              $transcriptReal.StartsWith($trustedPrefix, [System.StringComparison]::OrdinalIgnoreCase))) {
      Write-MarkerOnly
      exit 0
    }
  }
  if ($transcriptItem.Length -gt $MaxBytes) {
    Write-MarkerOnly
    exit 0
  }
}
catch {
  Write-MarkerOnly
  exit 0
}

# Detect format by scanning first 50 lines for a discriminator.
# CC transcripts often start with metadata (ai-title, mode, file-history-snapshot)
# before the first message, so the first line alone is unreliable.
function Detect-Format {
  param([string]$Path)
  $i = 0
  foreach ($line in Get-Content -Path $Path -Encoding UTF8 -ErrorAction SilentlyContinue) {
    $i++
    if ($i -gt 50) { break }
    if ([string]::IsNullOrEmpty($line)) { continue }
    if ($line -match '"type"\s*:\s*"session\.start"') { return "copilot" }
    if ($line -match '"message"' -and $line -match '"role"') { return "claude-code" }
  }
  return "unknown"
}

$format = Detect-Format -Path $Transcript
if ($format -eq "unknown") {
  Write-MarkerOnly
  exit 0
}

# Truncate to 200 chars, collapse newlines to spaces, escape markdown pipes.
function Truncate200 {
  param([string]$s)
  if ($s.Length -gt 200) { $s = $s.Substring(0, 200) }
  $s = $s -replace "`r`n", " "
  $s = $s -replace "`n", " "
  $s = $s -replace "`r", " "
  $s = $s -replace "\|", "\|"
  return $s
}

function Redact-Sensitive {
  param([string]$s)
  if ([string]::IsNullOrEmpty($s)) { return $s }
  $s = [regex]::Replace($s, 'ghp_[A-Za-z0-9_]{20,}', '[REDACTED]')
  $s = [regex]::Replace($s, 'github_pat_[A-Za-z0-9_]{20,}', '[REDACTED]')
  $s = [regex]::Replace($s, '([Aa]uthorization:\s*[Bb]earer\s+)[^\s]+', '$1[REDACTED]')
  $s = [regex]::Replace($s, '([Aa][Pp][Ii][_ -]?[Kk]ey\s*[:=]\s*)[^\s]+', '$1[REDACTED]')
  $s = [regex]::Replace($s, 'AKIA[0-9A-Z]{16}', '[REDACTED]')
  $s = [regex]::Replace($s, '([Pp]assword\s*[:=]\s*)[^\s"''`,;]+', '$1[REDACTED]')
  $s = [regex]::Replace($s, '([Pp]ass(?:wd)?\s*[:=]\s*)[^\s"''`,;]+', '$1[REDACTED]')
  $s = [regex]::Replace($s, '([Pp]wd\s*[:=]\s*)[^\s"''`,;]+', '$1[REDACTED]')
  $s = [regex]::Replace($s, '([Ss]ecret\s*[:=]\s*)[^\s"''`,;]+', '$1[REDACTED]')
  $s = [regex]::Replace($s, '([Tt]oken\s*[:=]\s*)[^\s"''`,;]+', '$1[REDACTED]')
  $s = [regex]::Replace($s, '([Cc]lient[_ -]?[Ss]ecret\s*[:=]\s*)[^\s"''`,;]+', '$1[REDACTED]')
  $s = [regex]::Replace($s, '([Pp]rivate[_ -]?[Kk]ey\s*[:=]\s*)[^\s"''`,;]+', '$1[REDACTED]')
  $s = [regex]::Replace($s, '\b([a-z][a-z0-9+.-]*://[^:\s/]+:)[^@\s/]+@', '$1[REDACTED]@', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
  $s = [regex]::Replace($s, '\b((?:export\s+)?[A-Z][A-Z0-9_]*(?:PASSWORD|PASSWD|PWD|SECRET|TOKEN|API_KEY|ACCESS_KEY|PRIVATE_KEY)[A-Z0-9_]*\s*=\s*)[^\s"''`]+', '$1[REDACTED]')
  $s = [regex]::Replace($s, '\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b', '[REDACTED]', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
  $s = [regex]::Replace($s, '\b(?:\+?\d{1,3}[-.\s]?)?(?:\(?\d{3}\)?[-.\s]?)\d{3}[-.\s]?\d{4}\b', '[REDACTED]')
  $s = [regex]::Replace($s, '\b\d{3}-\d{2}-\d{4}\b', '[REDACTED]')
  return $s
}

# Extract via ConvertFrom-Json. On any error, drop to marker-only.
function Extract-ClaudeCode {
  param([string]$Path)
  $lines = Get-Content -Path $Path -Encoding UTF8
  $firstPrompt = $null
  $toolCalls = [System.Collections.Generic.List[string]]::new()
  $lastText = $null
  $decisions = [System.Collections.Generic.List[string]]::new()
  $decisionPattern = 'APPROVED|DECIDED|CHOSE|DECISION|we will use|going with|let''s go with'

  foreach ($raw in $lines) {
    if ([string]::IsNullOrEmpty($raw)) { continue }
    try { $obj = $raw | ConvertFrom-Json -ErrorAction Stop }
    catch { continue }

    if ($obj.type -eq "user" -and $obj.message.role -eq "user") {
      $content = $obj.message.content
      if ($content -is [string]) {
        if (-not $content.StartsWith("<") -and [string]::IsNullOrEmpty($firstPrompt)) {
          $firstPrompt = $content
        }
      }
    }
    elseif ($obj.type -eq "assistant" -and $obj.message.content) {
      foreach ($entry in $obj.message.content) {
        if ($entry.type -eq "tool_use") {
          $target = $entry.input.file_path
          if ([string]::IsNullOrEmpty($target)) { $target = $entry.input.command }
          if ([string]::IsNullOrEmpty($target)) { $target = $entry.input.filePath }
          if ([string]::IsNullOrEmpty($target)) { $target = "unknown" }
          $toolCalls.Add("$($entry.name): $target")
        }
        elseif ($entry.type -eq "text") {
          $lastText = $entry.text
          if ($entry.text -match $decisionPattern) {
            $decisions.Add($entry.text)
          }
        }
      }
    }
  }

  # Dedupe before tail-10 (parity with extract-state.sh awk + opencode.plugin.js Set).
  $unique = [System.Collections.Generic.List[string]]::new()
  $seen = @{}
  foreach ($d in $decisions) {
    if (-not $seen.ContainsKey($d)) {
      $seen[$d] = $true
      $unique.Add($d)
    }
  }
  $decisions = $unique
  if ($decisions.Count -gt 10) {
    $decisions = $decisions.GetRange($decisions.Count - 10, 10)
  }

  Render-State $firstPrompt $toolCalls $lastText $decisions
}

function Extract-Copilot {
  param([string]$Path)
  $lines = Get-Content -Path $Path -Encoding UTF8
  $firstPrompt = $null
  $toolCalls = [System.Collections.Generic.List[string]]::new()
  $lastText = $null
  $decisions = [System.Collections.Generic.List[string]]::new()
  $decisionPattern = 'APPROVED|DECIDED|CHOSE|DECISION|we will use|going with|let''s go with'

  foreach ($raw in $lines) {
    if ([string]::IsNullOrEmpty($raw)) { continue }
    try { $obj = $raw | ConvertFrom-Json -ErrorAction Stop }
    catch { continue }

    if ($obj.type -eq "user.message") {
      $content = $obj.data.content
      if (-not [string]::IsNullOrEmpty($content) -and -not $content.StartsWith("<") -and [string]::IsNullOrEmpty($firstPrompt)) {
        $firstPrompt = $content
      }
    }
    elseif ($obj.type -eq "assistant.message") {
      $lastText = $obj.data.content
      $combined = $obj.data.content
      if ($obj.data.reasoningText) { $combined += "`n" + $obj.data.reasoningText }
      if ($combined -match $decisionPattern) {
        $decisions.Add($combined)
      }
      if ($obj.data.toolRequests) {
        foreach ($req in $obj.data.toolRequests) {
          $target = "unknown"
          try {
            $args = $req.arguments | ConvertFrom-Json -ErrorAction Stop
            if ($args.filePath) { $target = $args.filePath }
            elseif ($args.command) { $target = $args.command }
            elseif ($args.file_path) { $target = $args.file_path }
          }
          catch { $target = "unknown" }
          $toolCalls.Add("$($req.name): $target")
        }
      }
    }
  }

  # Dedupe before tail-10 (parity with extract-state.sh awk + opencode.plugin.js Set).
  $unique = [System.Collections.Generic.List[string]]::new()
  $seen = @{}
  foreach ($d in $decisions) {
    if (-not $seen.ContainsKey($d)) {
      $seen[$d] = $true
      $unique.Add($d)
    }
  }
  $decisions = $unique
  if ($decisions.Count -gt 10) {
    $decisions = $decisions.GetRange($decisions.Count - 10, 10)
  }

  Render-State $firstPrompt $toolCalls $lastText $decisions
}

function Render-State {
  param(
    [string]$firstPrompt,
    [System.Collections.Generic.List[string]]$toolCalls,
    [string]$lastText,
    [System.Collections.Generic.List[string]]$decisions
  )

  if ([string]::IsNullOrEmpty($firstPrompt) -and $toolCalls.Count -eq 0 -and [string]::IsNullOrEmpty($lastText)) {
    # Nothing extracted; marker-only.
    return $false
  }

  $firstPrompt = Redact-Sensitive $firstPrompt
  $lastText = Redact-Sensitive $lastText
  for ($i = 0; $i -lt $toolCalls.Count; $i++) { $toolCalls[$i] = Redact-Sensitive $toolCalls[$i] }
  for ($i = 0; $i -lt $decisions.Count; $i++) { $decisions[$i] = Redact-Sensitive $decisions[$i] }

  $firstPromptT = Truncate200 $firstPrompt
  $lastTextT = Truncate200 $lastText

  $sb = [System.Text.StringBuilder]::new()
  [void]$sb.AppendLine("# Agent State")
  [void]$sb.AppendLine("")
  [void]$sb.AppendLine("Session: ${stamp}-auto | Cwd: $cwd | Trigger: pre-compact-auto")
  [void]$sb.AppendLine("Created: $timestamp")
  [void]$sb.AppendLine("")
  [void]$sb.AppendLine("## Approved Workflow")
  if ($firstPromptT) {
    [void]$sb.AppendLine($firstPromptT)
  }
  else {
    [void]$sb.AppendLine("(not derivable from transcript)")
  }
  [void]$sb.AppendLine("")
  [void]$sb.AppendLine("## Position")
  [void]$sb.AppendLine("- **Current:** $lastTextT")
  [void]$sb.AppendLine("- **Done:**")
  if ($toolCalls.Count -gt 0) {
    foreach ($line in $toolCalls) {
      if ([string]::IsNullOrEmpty($line)) { continue }
      [void]$sb.AppendLine("  - $line ($timestamp)")
    }
  }
  else {
    [void]$sb.AppendLine("  (none extracted)")
  }
  [void]$sb.AppendLine("- **Remaining:** (not derivable from transcript)")
  [void]$sb.AppendLine("")
  [void]$sb.AppendLine("## Decision Log")
  if ($decisions.Count -gt 0) {
    foreach ($line in $decisions) {
      if ([string]::IsNullOrEmpty($line)) { continue }
      $snippet = Truncate200 $line
      [void]$sb.AppendLine("$timestamp AUTO-EXTRACTED: $snippet")
    }
  }
  else {
    [void]$sb.AppendLine("(none detected)")
  }
  [void]$sb.AppendLine("")
  [void]$sb.AppendLine("## Established Facts")
  [void]$sb.AppendLine("(auto-extracted; not reliably derivable from transcript shell parsing)")
  [void]$sb.AppendLine("")
  [void]$sb.AppendLine("## Re-derivation")
  [void]$sb.AppendLine("Read transcript at $Transcript for full session content.")
  [void]$sb.AppendLine("Read latest manual state file in .duck-tape/ for higher-fidelity checkpoint.")
  [void]$sb.AppendLine("")
  [void]$sb.AppendLine("## Suggested Skills")
  [void]$sb.AppendLine("- duck-tape (run /duck-tape for full state before next compaction)")

  Set-Content -Path $stateFile -Value $sb.ToString() -Encoding UTF8 -NoNewline

  # Rotation cap: 10 files. Eviction precedence: auto, recovered, manual.
  # Exclude the just-written state file so the fresh checkpoint survives.
  $all = Get-ChildItem -Path $DuckTapeDir -Filter "*.state.md" -File -ErrorAction SilentlyContinue
  $count = if ($all) { @($all).Count } else { 0 }
  while ($count -gt 10) {
    $autoFiles = Get-ChildItem -Path $DuckTapeDir -Filter "*-auto.state.md" -File -ErrorAction SilentlyContinue |
      Where-Object { $_.FullName -ne $stateFile }
    if ($autoFiles) {
      $oldest = $autoFiles | Sort-Object LastWriteTime | Select-Object -First 1
      Remove-Item -Path $oldest.FullName -Force
    }
    else {
      $recoveredFiles = Get-ChildItem -Path $DuckTapeDir -Filter "*-recovered.state.md" -File -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -ne $stateFile }
      if ($recoveredFiles) {
        $oldest = $recoveredFiles | Sort-Object LastWriteTime | Select-Object -First 1
        Remove-Item -Path $oldest.FullName -Force
      }
      else {
        # Re-query: $all captured at loop entry may include already-deleted files.
        $allCurrent = Get-ChildItem -Path $DuckTapeDir -Filter "*.state.md" -File -ErrorAction SilentlyContinue |
          Where-Object { $_.FullName -ne $stateFile }
        $oldest = $allCurrent | Sort-Object LastWriteTime | Select-Object -First 1
        Remove-Item -Path $oldest.FullName -Force
      }
    }
    $count--
  }

  # Marker points at newest state file.
  $latestAll = Get-ChildItem -Path $DuckTapeDir -Filter "*.state.md" -File -ErrorAction SilentlyContinue
  $latest = ($latestAll | Sort-Object LastWriteTime -Descending | Select-Object -First 1).Name
  $line = "$timestamp | cwd: $cwd | latest-state: $latest"
  if ($Transcript -and (Test-Path $Transcript -PathType Leaf)) { $line += " | transcript: $Transcript" }
  Set-Content -Path $marker -Value $line -Encoding UTF8 -NoNewline
  Write-Output $stateFile
  return $true
}

switch ($format) {
  "claude-code" {
    $ok = Extract-ClaudeCode -Path $Transcript
    if (-not $ok) { Write-MarkerOnly }
  }
  "copilot" {
    $ok = Extract-Copilot -Path $Transcript
    if (-not $ok) { Write-MarkerOnly }
  }
  default { Write-MarkerOnly }
}
