# duck-tape pre-compact trigger (PowerShell)
# Windows variant of pre-compact.sh. Writes .duck-tape/.last-compact marker only.
# No state stub, no merge.
[CmdletBinding()]
param(
  [string]$DuckTapeDir = (Join-Path (Get-Location) ".duck-tape")
)

$ErrorActionPreference = "Stop"

New-Item -ItemType Directory -Force -Path $DuckTapeDir | Out-Null

# .gitignore if missing
$gitignore = Join-Path $DuckTapeDir ".gitignore"
if (-not (Test-Path $gitignore)) {
  Set-Content -Path $gitignore -Value "*`n" -NoNewline
}

$timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
$cwd = (Get-Location).Path

# Find latest state file
$latestState = $null
$stateFiles = Get-ChildItem -Path $DuckTapeDir -Filter "*.state.md" -File -ErrorAction SilentlyContinue
if ($stateFiles) {
  $latestState = ($stateFiles | Sort-Object LastWriteTime -Descending | Select-Object -First 1).Name
}

# Write compaction marker
$marker = Join-Path $DuckTapeDir ".last-compact"
$line = "$timestamp | cwd: $cwd"
if ($latestState) { $line += " | latest-state: $latestState" }
Set-Content -Path $marker -Value $line -NoNewline

Write-Output $marker
