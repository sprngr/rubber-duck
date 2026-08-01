# Hooks Guide

Pre-compact trigger for duck-tape. Writes `.duck-tape/.last-compact` marker before context compaction. Skill reads marker at session resume to detect compaction occurred.

## What the trigger does

`pre-compact.sh` writes one line to `.duck-tape/.last-compact`:

```
2026-07-31T18:33:03Z | cwd: /project | latest-state: 2026-07-31-1200.state.md
```

No state stub. No merge. No CONTEXT.md write. Marker only.

## What the trigger does not do

- Does not capture session content. Shell scripts run outside LLM context.
- Does not merge into CONTEXT.md. Use `/duck-tape merge` for that.
- Does not re-inject context after compaction. Use `/duck-tape resume` to resume from checkpoint.

## Install per harness

### opencode

1. Copy `hooks/opencode.plugin.js` to `.opencode/plugins/duck-tape.js`.
2. No shell script needed. Plugin inlines marker logic in JS.
3. Restart opencode. Plugin loads at startup.

### Claude Code

**Unix (macOS/Linux):**
1. Merge `hooks/claude-code.hooks.json` content into `.claude/settings.json` under `hooks` key. If `hooks` exists, add `PreCompact` as sibling.
2. Confirm `src/skills/duck-tape/hooks/pre-compact.sh` exists in project root.
3. Run `/hooks` in Claude Code. Confirm `PreCompact` appears.

**Windows:**
1. Merge `hooks/claude-code.hooks.windows.json` content into `.claude/settings.json` under `hooks` key.
2. Confirm `src/skills/duck-tape/hooks/pre-compact.ps1` exists in project root.
3. Run `/hooks` in Claude Code. Confirm `PreCompact` appears.

Pick one variant. Do not merge both into the same settings file.

### Copilot CLI

1. Copy `hooks/copilot.hooks.json` to `.github/hooks/duck-tape.json` in repo root.
2. Config ships both `bash` and `powershell` fields. Host shell picks automatically. No user action needed on Windows.
3. Hooks load on next session start.

### Copilot cloud agent

1. Same as Copilot CLI. `.github/hooks/duck-tape.json` loads in sandbox.
2. Only `bash` field honored (Linux sandbox). `pre-compact.sh` runs in `/workspace`.
3. Marker writes to ephemeral sandbox. Lost when job ends. Useful only within same job if compaction occurs mid-job.

## Guided install

Run `/duck-tape init` for guided setup. Skill prompts for harness choice, writes correct config snippet, explains placement.

## Troubleshooting

**Marker not written after compaction:**
- Confirm hook config file in correct location per harness.
- Confirm `pre-compact.sh` is executable: `chmod +x src/skills/duck-tape/hooks/pre-compact.sh`.
- Check harness hook logs for errors.

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

## Portability notes

- All three harnesses run shell commands pre-compact. Behavior identical.
- No harness exposes context usage percentage to shell. No threshold detection.
- Only opencode can inject context into compaction summary (`output.context`). This trigger does not use that capability. Keeps behavior consistent across harnesses.
- Claude Code can re-inject post-compact via `SessionStart` matcher `compact`. This trigger does not use that. Skill handles resume via marker + guidance.
- Copilot cannot re-inject within compaction cycle. Relies on marker + skill guidance at next session start.

## Platform choice

`bash` is not guaranteed on Windows. Two script variants ship:
- `pre-compact.sh` — bash. Unix + Copilot cloud agent (Linux sandbox).
- `pre-compact.ps1` — PowerShell. Windows desktop (Claude Code, Copilot CLI).

### opencode

No platform choice needed. Plugin inlines marker logic in JS via Bun `fs`. No shell call. Cross-platform.

### Claude Code

Single `command` field, no platform branching. Two config files ship:
- `claude-code.hooks.json` — unix, calls `pre-compact.sh` via bash.
- `claude-code.hooks.windows.json` — Windows, calls `pre-compact.ps1` via powershell.

Merge one into `.claude/settings.json` under `hooks` key. Pick the one matching your platform. Do not merge both.

### Copilot CLI

Config has native `bash` and `powershell` fields. `copilot.hooks.json` ships both. Copilot runs the one matching the host shell. No user action needed on Windows.
