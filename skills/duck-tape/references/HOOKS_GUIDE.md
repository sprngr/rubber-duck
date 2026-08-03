# Hooks Guide

Pre-compact trigger for duck-tape. Writes `.duck-tape/.last-compact` marker and `.duck-tape/<id>-auto.state.md` state file before context compaction. Skill reads marker at session resume to detect compaction occurred, and reads state file to recover position.

## What the trigger does

`extract-state.sh` (or `.ps1`, or opencode plugin) parses the session transcript and writes a state file plus a one-line marker:

```
2026-07-31T18:33:03Z | cwd: /project | latest-state: 2026-07-31-1200-auto.state.md | transcript: /path/to/transcript.jsonl
```

Marker fields:
- `cwd`: working directory at compaction time
- `latest-state`: newest state file in `.duck-tape/` at compaction time
- `transcript`: source transcript path (Claude Code, Copilot) or opencode snapshot path (`<id>-transcript.json`). Absent in older markers written before Angle B, or when transcript was unavailable at compaction time.

State file `.duck-tape/<YYYY-MM-DD-HHMM>-auto.state.md` contains:
- **Approved Workflow:** first user prompt (truncated 200 chars)
- **Position:** last assistant text, all tool calls (cumulative)
- **Decision Log:** assistant text matching decision patterns (APPROVED/DECIDED/CHOSE/DECISION), deduped, last 10. Catches explicit decisions only. Implicit decisions ("we're going with X") missed by pattern matching, captured by Angle B LLM synthesis.
- **Re-derivation:** transcript path or session ID for full content

State file is auto-extracted, low-fidelity. Manual `/duck-tape` checkpoint produces higher-fidelity state. `/duck-tape resume` with LLM-assisted recovery (Angle B) produces `-recovered.state.md` with semantic decision extraction, between auto and manual in fidelity.

## Auto-checkpoint vs marker

- **Auto-checkpoint** (`extract-state.sh`/`.ps1`, opencode plugin): transcript parsing produces `<id>-auto.state.md` state file + marker. Runs on every compaction. No user action.
- **Marker-only** (`pre-compact.sh`/`.ps1`): writes marker line only. Retained as fallback if jq missing (bash), transcript missing, format unknown, or nothing extracted.
- **LLM-assisted recovery** (`extract-raw.sh`/`.ps1` + skill synthesis): runs on `/duck-tape resume` when only an auto-checkpoint exists or no state file exists. Produces `<id>-recovered.state.md` with semantic decision extraction from raw transcript material. Higher fidelity than auto, lower than manual.
- opencode plugin has no shell/jq dependency. Uses SDK to fetch session messages. Falls back to marker-only if SDK call fails or no client/sessionId. Plugin also writes `<id>-transcript.json` snapshot (messages since last state file) for Angle B recovery.

State files share the 10-file rotation cap. Eviction precedence: auto dropped first (oldest auto), then recovered, then manual.

## What the trigger does not do

- Does not capture full session content. Transcript parsing extracts four sections only. Use `/duck-tape` for full checkpoint.
- Does not merge into CONTEXT.md. Use `/duck-tape merge` for that.
- Does not re-inject context after compaction. Use `/duck-tape resume` to resume from checkpoint.

## LLM-assisted recovery (Angle B)

`/duck-tape resume` invokes LLM-assisted recovery when the only available state file is an auto-checkpoint (`-auto` suffix) or no state file exists. Recovery flow:

1. Skill reads marker `transcript` field. If absent, no recovery possible. Report and suggest `/duck-tape` for fresh checkpoint.
2. Skill runs `extract-raw.sh <transcript_path>` (bash) or `extract-raw.ps1 <transcript_path>` (PowerShell). Script outputs structured markdown: user prompts (chronological), tool calls (chronological), last 10 assistant messages, failed tool results, session metadata.
3. Skill reads raw material, synthesizes Agent State file with semantic understanding of decisions, position, facts. Higher fidelity than auto-checkpoint pattern matching.
4. Skill writes `.duck-tape/<YYYY-MM-DD-HHMM>-recovered.state.md`. State file write requires approval.
5. Skill reports position from new file.

`extract-raw.sh`/`.ps1` supports three input formats:
- Claude Code JSONL (message.role present)
- Copilot JSONL (type:"user.message"/"assistant.message")
- opencode JSON array (`{ info, parts }` shape, from `<id>-transcript.json` snapshot)

opencode snapshot: plugin writes incremental `<id>-transcript.json` at pre-compact time, containing messages created after the last existing state file's mtime. Keeps snapshot bounded for long sessions.

Recovery is reactive. Angle A (auto-checkpoint) is proactive. Both complement: Angle A catches sessions where user forgets to resume; Angle B produces better state when user does resume.

## Dependencies

**bash (Claude Code unix, Copilot unix/Linux):** requires `jq` for transcript parsing. Standard on macOS (Homebrew), most Linux distros. Windows Claude Code users need jq in PATH (Git Bash includes it, or install separately). If jq missing, script falls back to marker-only. `extract-raw.sh` also requires `jq`.

**PowerShell (Claude Code Windows, Copilot Windows):** no external dependency. Uses built-in `ConvertFrom-Json`.

**opencode:** no external dependency. Plugin uses opencode SDK client. Cross-platform.

**Performance:** both `extract-state.sh` and `extract-raw.sh` process 1MB+ transcripts in under 120ms. Well within Copilot's 10s hook timeout. No size limit needed for typical sessions.

## Install per harness

### opencode

1. Copy `hooks/opencode.plugin.js` to `.opencode/plugins/duck-tape.js`.
2. No shell script needed. Plugin fetches session messages via SDK, extracts state, writes state file + marker.
3. Restart opencode. Plugin loads at startup.

### Claude Code

**Unix (macOS/Linux):**
1. Merge `hooks/claude-code.hooks.json` content into `.claude/settings.json` under `hooks` key. If `hooks` exists, add `PreCompact` as sibling.
2. Confirm `src/skills/duck-tape/hooks/extract-state.sh` exists in project root.
3. Run `/hooks` in Claude Code. Confirm `PreCompact` appears.

**Windows:**
1. Merge `hooks/claude-code.hooks.windows.json` content into `.claude/settings.json` under `hooks` key.
2. Confirm `src/skills/duck-tape/hooks/extract-state.ps1` exists in project root.
3. Run `/hooks` in Claude Code. Confirm `PreCompact` appears.

Pick one variant. Do not merge both into the same settings file.

### Copilot CLI

1. Copy `hooks/copilot.hooks.json` to `.github/hooks/duck-tape.json` in repo root.
2. Config ships both `bash` and `powershell` fields. Host shell picks automatically. No user action needed on Windows.
3. Hooks load on next session start.

### Copilot cloud agent

1. Same as Copilot CLI. `.github/hooks/duck-tape.json` loads in sandbox.
2. Only `bash` field honored (Linux sandbox). `extract-state.sh` runs in `/workspace`.
3. State file + marker write to ephemeral sandbox. Lost when job ends. Useful only within same job if compaction occurs mid-job.

## Guided install

Run `/duck-tape init` for guided setup. Skill prompts for harness choice, writes correct config snippet, explains placement.

## Troubleshooting

**Marker not written after compaction:**
- Confirm hook config file in correct location per harness.
- Confirm `extract-state.sh` is executable: `chmod +x src/skills/duck-tape/hooks/extract-state.sh`.
- Check harness hook logs for errors.

**State file not written (marker only):**
- Bash: confirm `jq` installed and in PATH. If missing, script falls back to marker-only. Install jq or accept marker-only fallback.
- Confirm transcript path passed to script via hook input (stdin JSON `transcript_path` for Claude Code, `transcriptPath` for Copilot).
- opencode: confirm `client` and `sessionId` passed to plugin. If absent, plugin falls back to marker-only.

**Marker written but skill does not resume:**
- Skill checks `.duck-tape/.last-compact` on `/duck-tape resume`. Confirm file exists.
- Confirm latest state file referenced in marker still exists in `.duck-tape/`.

**opencode plugin not loading:**
- Confirm file at `.opencode/plugins/duck-tape.js`.
- Check for syntax errors in plugin file.
- Restart opencode.

**Claude Code hook not firing:**
- Run `/hooks`. Confirm `PreCompact` listed with count.
- Confirm `$CLAUDE_PROJECT_DIR` resolves correctly.
- Check `.claude/settings.json` is valid JSON.

**Copilot hook not firing:**
- Confirm `.github/hooks/duck-tape.json` is valid JSON with `"version": 1`.
- Confirm `preCompact` event name (camelCase).
- Check hook timeout: default 10s. Increase if script slow.

**Resume without transcript path in marker:**
- Markers written before Angle B lack the `transcript` field. Angle B recovery cannot run without it.
- Copilot transcript locations (for manual recovery if marker missing):
  - Windows: `C:\Users\<user>\AppData\Roaming\Code\User\workspaceStorage\<id>\GitHub.copilot-chat\transcripts\`
  - Linux: `~/.config/Code/User/workspaceStorage/<id>/GitHub.copilot-chat/transcripts/`
  - Mac: `~/Library/Application Support/Code/User/workspaceStorage/<id>/GitHub.copilot-chat/transcripts/`
  - `<id>` is workspace storage ID, not session ID. Skill cannot derive without listing directory. Recommend: rely on marker. If marker missing, run `/duck-tape` for fresh checkpoint instead of recovery.
- Claude Code: transcript at `~/.claude/projects/<encoded-cwd>/<session-id>.jsonl`. Can be derived from session metadata if marker stores session ID.

## Portability notes

- All three harnesses run pre-compact. Behavior identical: state file + marker.
- No harness exposes context usage percentage to shell. No threshold detection.
- Only opencode can inject context into compaction summary (`output.context`). This trigger does not use that capability. Keeps behavior consistent across harnesses.
- Claude Code can re-inject post-compact via `SessionStart` matcher `compact`. This trigger does not use that. Skill handles resume via marker + state file + guidance.
- Copilot cannot re-inject within compaction cycle. Relies on marker + state file + skill guidance at next session start.

## Platform choice

`bash` is not guaranteed on Windows. Two script variants ship per script type:
- `extract-state.sh` — bash + jq. Auto-checkpoint extractor. Unix + Copilot cloud agent (Linux sandbox).
- `extract-state.ps1` — PowerShell. Auto-checkpoint extractor. Windows desktop (Claude Code, Copilot CLI).
- `extract-raw.sh` — bash + jq. Raw material extractor for LLM-assisted recovery. Unix + Copilot cloud agent.
- `extract-raw.ps1` — PowerShell. Raw material extractor for LLM-assisted recovery. Windows desktop.

`pre-compact.sh` and `pre-compact.ps1` retained as marker-only fallback scripts.

### opencode

No platform choice needed. Plugin fetches messages via SDK, extracts state, writes state file + marker. No shell call. Cross-platform.

### Claude Code

Single `command` field, no platform branching. Two config files ship:
- `claude-code.hooks.json` — unix, calls `extract-state.sh` via bash.
- `claude-code.hooks.windows.json` — Windows, calls `extract-state.ps1` via powershell.

Merge one into `.claude/settings.json` under `hooks` key. Pick the one matching your platform. Do not merge both.

### Copilot CLI

Config has native `bash` and `powershell` fields. `copilot.hooks.json` ships both. Copilot runs the one matching the host shell. No user action needed on Windows.
