# session-start hook for Claude Code (Windows)
# Reads SessionStart JSON from stdin; if agent_type == "rubber-duck", emits
# hookSpecificOutput.additionalContext with the shared directive. No-op otherwise.
$ErrorActionPreference = "Stop"

$projectDir = $env:CLAUDE_PROJECT_DIR
if (-not $projectDir) { $projectDir = (Get-Location).Path }

$directiveCandidates = @(
  (Join-Path $projectDir ".opencode\session-start.directive.md"),
  (Join-Path $projectDir ".agents\session-start.directive.md")
)

# Read stdin once
$stdinJson = [Console]::In.ReadToEnd()
if ([string]::IsNullOrWhiteSpace($stdinJson)) { exit 0 }

# Extract agent_type. Missing or not rubber-duck => silent no-op.
$agentType = ($stdinJson | ConvertFrom-Json).agent_type
if ($agentType -ne "rubber-duck") { exit 0 }

# Locate and read directive
$directive = $null
foreach ($candidate in $directiveCandidates) {
  if (Test-Path $candidate) {
    $directive = Get-Content -Path $candidate -Raw
    break
  }
}
if ([string]::IsNullOrEmpty($directive)) { exit 0 }

# Emit additionalContext (ConvertTo-Json handles escaping)
$output = @{
  hookSpecificOutput = @{
    hookEventName      = "SessionStart"
    additionalContext  = $directive
  }
}
$output | ConvertTo-Json -Depth 4
