# duck-tape raw transcript extractor (Angle B: LLM-assisted recovery) - PowerShell
# Windows variant of extract-raw.sh. Reads a session transcript, extracts raw
# material into structured markdown for LLM synthesis during /duck-tape resume.
# Does NOT synthesize state.
#
# Supports three input formats:
#   - Claude Code JSONL (one JSON object per line, message.role present)
#   - Copilot JSONL (one JSON object per line, type:"user.message"/"assistant.message")
#   - opencode JSON array (single JSON document, [{ info, parts }])
#
# Outputs structured markdown to stdout. Falls back to "transcript too large,
# read manually" message if transcript unreadable or format unknown.
[CmdletBinding()]
param(
  [Parameter(Position = 0)]
  [string]$Transcript = ""
)

$ErrorActionPreference = "Stop"
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

if ([string]::IsNullOrEmpty($Transcript) -or -not (Test-Path $Transcript -PathType Leaf)) {
  [Console]::Error.WriteLine("Transcript not found: $(if ($Transcript) { $Transcript } else { '<none>' })")
  Write-Output "# Transcript Raw Material`n`nTranscript not available. Read session manually."
  exit 0
}

# Detect format.
# opencode snapshot = single JSON array (not JSONL). Detect by first non-space char.
# CC/Copilot = JSONL. CC has message/role, Copilot has type:"*.message".
function Detect-Format {
  param([string]$Path)
  $first = ""
  try {
    $stream = [System.IO.File]::OpenRead($Path)
    $buffer = New-Object byte[] 1
    [void]$stream.Read($buffer, 0, 1)
    $stream.Close()
    $first = [char]$buffer[0]
  } catch { return "unknown" }

  if ($first -eq "[") { return "opencode" }

  $lineNum = 0
  try {
    $reader = [System.IO.StreamReader]::new($Path, [System.Text.Encoding]::UTF8)
    while (-not $reader.EndOfStream -and $lineNum -lt 50) {
      $line = $reader.ReadLine()
      $lineNum++
      if ([string]::IsNullOrWhiteSpace($line)) { continue }
      if ($line -match '"type":"session.start"') { $reader.Close(); return "copilot" }
      if ($line -match '"message"' -and $line -match '"role"') { $reader.Close(); return "claude-code" }
    }
    $reader.Close()
  } catch { }
  return "unknown"
}

# Convert epoch ms to ISO 8601 UTC string.
function Convert-EpochMs {
  param([long]$Ms)
  if ($Ms -le 0) { return "unknown" }
  try {
    $dt = [DateTimeOffset]::FromUnixTimeMilliseconds($Ms).UtcDateTime
    return $dt.ToString("yyyy-MM-ddTHH:mm:ssZ")
  } catch { return $Ms.ToString() }
}

function Write-SessionMeta {
  param([string]$T, [string]$Fmt)
  $start = "unknown"
  $cwd = (Get-Location).Path
  $branch = "unknown"
  try {
    $branch = (git rev-parse --abbrev-ref HEAD 2>$null) ?? "unknown"
  } catch { }

  if ($Fmt -eq "claude-code") {
    try {
      $firstUser = Get-Content -Path $T -Encoding UTF8 -TotalCount 50 | ForEach-Object {
        try { $_ | ConvertFrom-Json -ErrorAction Stop } catch { $null }
      } | Where-Object { $_.type -eq "user" -and $_.timestamp } | Select-Object -First 1
      if ($firstUser) { $start = $firstUser.timestamp }
    } catch { }
  } elseif ($Fmt -eq "copilot") {
    try {
      $firstStart = Get-Content -Path $T -Encoding UTF8 -TotalCount 50 | ForEach-Object {
        try { $_ | ConvertFrom-Json -ErrorAction Stop } catch { $null }
      } | Where-Object { $_.type -eq "session.start" -and $_.timestamp } | Select-Object -First 1
      if ($firstStart) { $start = $firstStart.timestamp }
    } catch { }
  } elseif ($Fmt -eq "opencode") {
    try {
      $doc = Get-Content -Path $T -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
      if ($doc -and $doc.Count -gt 0 -and $doc[0].info.time.created) {
        $start = Convert-EpochMs $doc[0].info.time.created
      }
    } catch { }
  }

  Write-Output "## Session Metadata"
  Write-Output "- Start: $start"
  Write-Output "- Cwd: $cwd"
  Write-Output "- Branch: $branch`n"
}

function Extract-ClaudeCode {
  param([string]$T)
  Write-Output "# Transcript Raw Material`n"

  $records = @()
  try {
    $records = Get-Content -Path $T -Encoding UTF8 | ForEach-Object {
      if ([string]::IsNullOrWhiteSpace($_)) { return }
      try { $_ | ConvertFrom-Json -ErrorAction Stop } catch { }
    } | Where-Object { $_ }
  } catch { }

  # User Prompts
  Write-Output "## User Prompts (chronological)"
  $idx = 0
  foreach ($r in ($records | Where-Object {
    $_.type -eq "user" -and $_.message.role -eq "user" -and $_.message.content -is [string]
  })) {
    $idx++
    Write-Output "$idx. $($r.timestamp): $($r.message.content)"
  }
  Write-Output ""

  # Tool Calls
  Write-Output "## Tool Calls (chronological)"
  $idx = 0
  foreach ($r in ($records | Where-Object { $_.type -eq "assistant" })) {
    if (-not $r.message.content) { continue }
    foreach ($part in $r.message.content) {
      if ($part.type -ne "tool_use") { continue }
      $target = $part.input.file_path
      if (-not $target) { $target = $part.input.command }
      if (-not $target) { $target = $part.input.filePath }
      if (-not $target) { $target = "unknown" }
      $idx++
      Write-Output "$idx. $($r.timestamp): $($part.name) on $target"
    }
  }
  Write-Output ""

  # Assistant Messages (last 10)
  Write-Output "## Assistant Messages (last 10, chronological)"
  $texts = @()
  foreach ($r in ($records | Where-Object { $_.type -eq "assistant" })) {
    if (-not $r.message.content) { continue }
    foreach ($part in $r.message.content) {
      if ($part.type -eq "text" -and $part.text) {
        $texts += "$($r.timestamp): $($part.text)"
      }
    }
  }
  $idx = 0
  foreach ($t in ($texts | Select-Object -Last 10)) {
    $idx++
    Write-Output "$idx. $t"
  }
  Write-Output ""

  # Potential Decisions (all matching, deduped)
  Write-Output "## Potential Decisions (all matching, chronological, deduped)"
  $decisionPattern = 'APPROVED|DECIDED|CHOSE|DECISION|we will use|going with|let''s go with'
  $decisions = @()
  $seen = @{}
  foreach ($t in $texts) {
    if ($t -match $decisionPattern -and -not $seen.ContainsKey($t)) {
      $seen[$t] = $true
      $decisions += $t
    }
  }
  $idx = 0
  foreach ($d in $decisions) {
    $idx++
    Write-Output "$idx. $d"
  }
  Write-Output ""

  # Failed Tool Results
  Write-Output "## Failed Tool Results"
  $idx = 0
  foreach ($r in ($records | Where-Object { $_.type -eq "user" })) {
    if (-not $r.message.content -or ($r.message.content -is [string])) { continue }
    foreach ($part in $r.message.content) {
      if ($part.type -ne "tool_result") { continue }
      if (-not $part.is_error) { continue }
      $content = $part.content
      if ($content -isnot [string]) {
        $content = ($part.content | Where-Object { $_.type -eq "text" } | Select-Object -First 1).text
      }
      $idx++
      Write-Output "$idx. $content"
    }
  }
  Write-Output ""

  Write-SessionMeta $T "claude-code"
}

function Extract-Copilot {
  param([string]$T)
  Write-Output "# Transcript Raw Material`n"

  $records = @()
  try {
    $records = Get-Content -Path $T -Encoding UTF8 | ForEach-Object {
      if ([string]::IsNullOrWhiteSpace($_)) { return }
      try { $_ | ConvertFrom-Json -ErrorAction Stop } catch { }
    } | Where-Object { $_ }
  } catch { }

  # User Prompts
  Write-Output "## User Prompts (chronological)"
  $idx = 0
  foreach ($r in ($records | Where-Object { $_.type -eq "user.message" -and $_.data.content })) {
    $idx++
    Write-Output "$idx. $($r.timestamp): $($r.data.content)"
  }
  Write-Output ""

  # Tool Calls
  Write-Output "## Tool Calls (chronological)"
  $idx = 0
  foreach ($r in ($records | Where-Object { $_.type -eq "assistant.message" })) {
    if (-not $r.data.toolRequests) { continue }
    foreach ($tr in $r.data.toolRequests) {
      $target = "unknown"
      try {
        $args = $tr.arguments | ConvertFrom-Json -ErrorAction Stop
        $target = $args.filePath
        if (-not $target) { $target = $args.command }
        if (-not $target) { $target = $args.file_path }
        if (-not $target) { $target = "unknown" }
      } catch { }
      $idx++
      Write-Output "$idx. $($r.timestamp): $($tr.name) on $target"
    }
  }
  Write-Output ""

  # Assistant Messages (last 10)
  Write-Output "## Assistant Messages (last 10, chronological)"
  $idx = 0
  foreach ($t in ($records | Where-Object { $_.type -eq "assistant.message" -and $_.data.content } |
                  Select-Object -Last 10)) {
    $idx++
    Write-Output "$idx. $($t.timestamp): $($t.data.content)"
  }
  Write-Output ""

  # Potential Decisions (all matching, deduped)
  Write-Output "## Potential Decisions (all matching, chronological, deduped)"
  $decisionPattern = 'APPROVED|DECIDED|CHOSE|DECISION|we will use|going with|let''s go with'
  $copilotTexts = @()
  foreach ($r in ($records | Where-Object { $_.type -eq "assistant.message" -and $_.data.content })) {
    $copilotTexts += "$($r.timestamp): $($r.data.content)"
    if ($r.data.reasoningText) { $copilotTexts += "$($r.timestamp): $($r.data.reasoningText)" }
  }
  $decisions = @()
  $seen = @{}
  foreach ($t in $copilotTexts) {
    if ($t -match $decisionPattern -and -not $seen.ContainsKey($t)) {
      $seen[$t] = $true
      $decisions += $t
    }
  }
  $idx = 0
  foreach ($d in $decisions) {
    $idx++
    Write-Output "$idx. $d"
  }
  Write-Output ""

  # Failed Tool Results
  Write-Output "## Failed Tool Results"
  $idx = 0
  foreach ($r in ($records | Where-Object { $_.type -eq "tool.message" -and $_.data.isError -eq $true })) {
    $content = $r.data.content
    if (-not $content) { $content = $r.data.error }
    if (-not $content) { $content = "unknown error" }
    $idx++
    Write-Output "$idx. $($r.timestamp): $content"
  }
  Write-Output ""

  Write-SessionMeta $T "copilot"
}

function Extract-OpenCode {
  param([string]$T)
  Write-Output "# Transcript Raw Material`n"

  $messages = @()
  try {
    $messages = Get-Content -Path $T -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
  } catch { }

  # User Prompts
  Write-Output "## User Prompts (chronological)"
  $idx = 0
  foreach ($m in ($messages | Where-Object { $_.info.role -eq "user" })) {
    if (-not $m.parts) { continue }
    foreach ($part in $m.parts) {
      if ($part.type -eq "text" -and $part.text) {
        $idx++
        Write-Output "$idx. $(Convert-EpochMs $m.info.time.created): $($part.text)"
      }
    }
  }
  Write-Output ""

  # Tool Calls
  Write-Output "## Tool Calls (chronological)"
  $idx = 0
  foreach ($m in ($messages | Where-Object { $_.info.role -eq "assistant" })) {
    if (-not $m.parts) { continue }
    foreach ($part in $m.parts) {
      if ($part.type -ne "tool") { continue }
      $target = $part.state.input.file_path
      if (-not $target) { $target = $part.state.input.command }
      if (-not $target) { $target = $part.state.input.filePath }
      if (-not $target) { $target = "unknown" }
      $idx++
      Write-Output "$idx. $(Convert-EpochMs $m.info.time.created): $($part.tool) on $target"
    }
  }
  Write-Output ""

  # Assistant Messages (last 10)
  Write-Output "## Assistant Messages (last 10, chronological)"
  $texts = @()
  foreach ($m in ($messages | Where-Object { $_.info.role -eq "assistant" })) {
    if (-not $m.parts) { continue }
    foreach ($part in $m.parts) {
      if ($part.type -eq "text" -and $part.text) {
        $texts += "$(Convert-EpochMs $m.info.time.created): $($part.text)"
      }
    }
  }
  $idx = 0
  foreach ($t in ($texts | Select-Object -Last 10)) {
    $idx++
    Write-Output "$idx. $t"
  }
  Write-Output ""

  # Potential Decisions (all matching, deduped)
  Write-Output "## Potential Decisions (all matching, chronological, deduped)"
  $decisionPattern = 'APPROVED|DECIDED|CHOSE|DECISION|we will use|going with|let''s go with'
  $decisions = @()
  $seen = @{}
  foreach ($t in $texts) {
    if ($t -match $decisionPattern -and -not $seen.ContainsKey($t)) {
      $seen[$t] = $true
      $decisions += $t
    }
  }
  $idx = 0
  foreach ($d in $decisions) {
    $idx++
    Write-Output "$idx. $d"
  }
  Write-Output ""

  # Failed Tool Results
  Write-Output "## Failed Tool Results"
  $idx = 0
  foreach ($m in ($messages | Where-Object { $_.info.role -eq "assistant" })) {
    if (-not $m.parts) { continue }
    foreach ($part in $m.parts) {
      if ($part.type -ne "tool") { continue }
      $isError = $part.state.status -eq "error" -or $part.state.error
      if (-not $isError) { continue }
      $err = $part.state.error
      if (-not $err) { $err = $part.state.output }
      if (-not $err) { $err = "unknown error" }
      if ($err -isnot [string]) { $err = $err | ConvertTo-Json -Compress }
      $idx++
      Write-Output "$idx. $(Convert-EpochMs $m.info.time.created): $($part.tool): $err"
    }
  }
  Write-Output ""

  Write-SessionMeta $T "opencode"
}

$format = Detect-Format $Transcript

switch ($format) {
  "claude-code" { Extract-ClaudeCode $Transcript }
  "copilot" { Extract-Copilot $Transcript }
  "opencode" { Extract-OpenCode $Transcript }
  default { Write-Output "# Transcript Raw Material`n`nFormat unknown.`n" }
}
