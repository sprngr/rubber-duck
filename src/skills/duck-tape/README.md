# duck-tape: Session Memory Management 🦆📼

Two-tier memory system for AI agent sessions. Tier 1 persists long-term context into `CONTEXT.md`. Tier 2 captures working session state into `.duck-tape/` for handoff between sessions.

## Why Two Tiers

Not every session deserves permanent context. State files capture the full picture for recovery. CONTEXT.md holds only what advances the project long-term.

**Tier 1 — `CONTEXT.md`** (persistent, repo-tracked)
- Long-term memory across sessions
- 8 fixed schema sections with deterministic merge rules
- Committed to version control
- Merged from state files only on explicit merge signals

**Tier 2 — `.duck-tape/<id>.state.md`** (working, not committed)
- Short-term session state
- Agent State schema with position tracking, decisions, facts
- Auto-ignored (`.gitignore` created automatically)
- Rotated after 10 files (oldest dropped)
- Staging input for CONTEXT.md merges

## Commands

### `/duck-tape` — Save session state (default)

Writes session state file only. Does not touch CONTEXT.md.

**Use when:** checkpointing progress, saving work before switching tasks, capturing state for potential recovery.

### `/duck-tape merge` — Merge into CONTEXT.md

Writes session state file, then merges translated content into CONTEXT.md.

**Use when:** the session produced decisions, conventions, or facts that belong in long-term memory.

### `compact session` / `persist memory` / `update CONTEXT.md`

Alias for `/duck-tape merge`. Same behavior.

### `/duck-tape prune` — Cull Notes entries

Lists timestamped Notes entries in CONTEXT.md. You pick which to remove. Fixed-schema sections are never touched.

**Use when:** CONTEXT.md Notes section grows too large. Old observations that no longer matter.

### `/duck-tape migrate` — Restructure CONTEXT.md

Classifies freeform content in an existing CONTEXT.md into schema sections. Proposes the restructure before executing.

**Use when:** you have a CONTEXT.md that predates the schema or drifted from structure.

### `/duck-tape init` — Guided hook install

Prompts for harness choice (opencode, Claude Code, Copilot) and platform (unix/Windows for Claude Code). Writes the correct hook config snippet to the right path. Explains placement.

**Use when:** setting up pre-compact trigger for the first time. See `references/HOOKS_GUIDE.md` for manual install.

### `/duck-tape resume` — Reload from compaction

Checks `.duck-tape/.last-compact` marker. If compaction occurred this session, reads latest state file and CONTEXT.md. Reports position, decisions, and facts. Read-only. No writes.

**Use when:** compaction may have occurred and you lost context. Signal: "resume session".

## Typical Workflow

Five scenarios covering the session lifecycle.

### First-time setup

1. Run `/duck-tape init`. Pick your harness (opencode, Claude Code, Copilot). Skill writes hook config to the right path.
2. Confirm `hooks/extract-state.sh` (unix) or `hooks/extract-state.ps1` (Windows) is in project. opencode skips this (JS plugin fetches via SDK).
3. Start working. Hook fires automatically on compaction. Writes `.duck-tape/.last-compact` marker and `.duck-tape/<id>-auto.state.md` state file with auto-extracted content (Approved Workflow, Position, Decision Log). Falls back to marker-only if jq missing (bash), transcript missing, or parse fails.

### During a session

1. Checkpoint after completing a logical unit of work: feature done, decision made, bug fixed.
2. Run `/duck-tape` or say "checkpoint session". Skill writes state file with position, decisions, facts.
3. Continue working. Repeat as needed. State files rotate (max 10, oldest dropped).
4. No need to checkpoint mid-thought. State files capture where you are, not every keystroke.

### After compaction

1. If you notice missing detail or context feels summarized, compaction may have occurred.
2. Run `/duck-tape resume` or say "resume session". Skill checks `.duck-tape/.last-compact` marker.
3. If marker is newer than session start: compaction occurred. Skill reads latest state file and CONTEXT.md. Reports position, decisions, facts.
4. Pick up where you left off. No files written. Read-only recovery.

### End of a session

1. Ask: did this session produce decisions, conventions, or facts worth keeping long-term?
2. If yes: run `/duck-tape merge` or say "compact session". Skill writes state file, then merges translated content into CONTEXT.md. Changelog reports what changed.
3. If no: run `/duck-tape` for a state-only checkpoint. State file stays in `.duck-tape/` for recovery. CONTEXT.md untouched.
4. If CONTEXT.md does not exist yet: merge triggers bootstrap. Skill creates CONTEXT.md with scaffold from state file content.

### Periodic maintenance

1. Check CONTEXT.md Notes section size. If it grew large, run `/duck-tape prune`. Pick stale entries to remove. Fixed-schema sections are never touched.
2. Review Deferred-Debt entries. Update status markers as decisions get made.
3. If CONTEXT.md drifted from schema (freeform content outside the 8 sections), run `/duck-tape migrate`. Skill classifies content and proposes restructure.
4. Check `.duck-tape/` for old state files. Rotation handles this automatically (max 10), but verify if disk space matters.

## Context Hygiene

Good context hygiene keeps CONTEXT.md useful. Bad hygiene turns it into noise.

### When to merge

Merge into CONTEXT.md when the session produced:
- **Decisions** that constrain future work (architecture choices, API contracts, naming conventions)
- **Conventions** that other contributors need to follow
- **Glossary terms** that recur across sessions
- **Open questions** that block progress and need tracking
- **Deferred debt** with concrete revisit triggers

Skip merge when the session was:
- Exploratory research with no conclusions
- Debugging that resolved without lasting impact
- Conversational (teaching, explaining, brainstorming without decisions)
- Transient (fixing a typo, running a script, checking status)

### When to prune

Prune Notes entries when:
- The observation is stale (older decision superseded it)
- The detail is available elsewhere (code, docs, tickets)
- The entry is pure scratch-work (derivation steps you don't need to revisit)

Never prune fixed-schema sections via prune. Those merge only.

### CONTEXT.md schema overview

```
## Goals           — What the project optimizes for
## Decisions       — Explicit choices made in session
## Conventions     — Project patterns and rules
## Glossary        — Domain terms and definitions
## Deferred-Debt   — Deferred work with status markers
## Open-Questions  — Unresolved questions
## Session-Log     — Timestamped session entries (capped at 50)
## Notes           — Freeform observations (append-only, prune-safe)
```

### Keeping CONTEXT.md small

- **One entry, one line.** Decisions and conventions are single-line keyed entries.
- **Supersede, don't accumulate.** When a decision changes, the old entry is replaced. The changelog records what changed.
- **Session-Log rotates.** Oldest entries drop at 50. Don't use Session-Log for anything you need forever.
- **Notes is the dump zone.** Freeform content goes here. Prune it when it stops being useful.
- **Never infer Goals or Conventions.** These sections get entries only from explicit user decisions.

## Session State Schema

State files use the Agent State schema:

```
# Agent State

Session: <id> | Cwd: <path> | Repo/Branch: <repo>@<branch>
Created: <ISO-8601> | Updated: <ISO-8601> | Compactions: 0

## Approved Workflow
<what was approved, link spec/plan/ticket>

## Position
- **Current:** <step in flight>
- **Done:** <ordered newest last>
- **Remaining:** <in order>

## Decision Log
<ISO-8601> APPROVED/REJECTED: <what> - <reasoning>

## Established Facts
<facts established during session>

## Re-derivation
<how to recover state: commands, files, endpoints>

## Suggested Skills
<optional, skills for next session>
```

The state file translates into CONTEXT.md via a rigid map:
- Approved Workflow + Decision Log → **Decisions**
- Position.Current + Position.Done → **Session-Log**
- Position.Remaining → **Open-Questions**
- Established Facts → **Glossary**
- Re-derivation → **Notes** (verbatim)
- Suggested Skills → consumed by next agent, not merged

## Harness Integration

Pre-compact trigger writes `.duck-tape/.last-compact` marker and `.duck-tape/<id>-auto.state.md` state file before context compaction. State file is auto-extracted from the session transcript (Claude Code, Copilot) or fetched via SDK (opencode). Contains auto-extracted Approved Workflow, Position (tool calls + last assistant text), and Decision Log (pattern-matched). Low-fidelity recovery fallback — manual `/duck-tape` checkpoint produces higher-fidelity state.

**Fallback:** marker-only on failure. jq missing (bash), transcript missing, format unknown, nothing extracted, SDK error (opencode). `pre-compact.sh`/`.ps1` retained as marker-only fallback scripts.

**Resume from compaction:** triggered by `/duck-tape resume` or "resume session". Skill checks `.duck-tape/.last-compact`. If marker exists and is newer than session start, compaction occurred. Skill reads `CONTEXT.md` and latest state file to resume from checkpoint. Auto state files use `-auto` suffix; manual checkpoints have no suffix. Marker `latest-state` points at newest file regardless of suffix.

**Behavior identical across opencode, Claude Code, and Copilot.** No threshold detection. No context re-injection. State file + marker.

**Install:** run `/duck-tape init` for guided setup, or see `references/HOOKS_GUIDE.md` for manual install per harness.

## Security

Redaction runs before every write. Secrets, API keys, tokens, passwords, and PII are detected and blocked. You must confirm masking (`<REDACTED>`) before any flagged content reaches persistent storage.

Redaction applies to both tiers (CONTEXT.md and state files).

## Troubleshooting

**CONTEXT.md lacks schema sections.** Run `/duck-tape migrate` to classify existing content and append missing headers.

**State files accumulating.** Check rotation cap (max 10). Oldest files drop automatically. If you need to recover a dropped state, check CONTEXT.md Session-Log for the dropped ID.

**Merge produced unexpected entries.** Check the changelog. Each addition, supersession, and drop is logged with a reason. Use `/duck-tape prune` to clean Notes if needed.

## File Layout

```
<project>/
  CONTEXT.md                    — Tier 1 persistent memory
  .duck-tape/
    .gitignore                  — `*` (auto-created)
    .last-compact               — pre-compact marker (harness-written)
    <YYYY-MM-DD-HHMM>.state.md      — Tier 2 working state (manual /duck-tape)
    <YYYY-MM-DD-HHMM>-auto.state.md — Tier 2 auto-extracted state (pre-compact hook)
```

## References

- `references/SCHEMA.md` — full CONTEXT.md schema definitions and merge rules
- `references/STATE_SCHEMA.md` — Agent State schema and translation map
- `references/OUTPUT_SCHEMA.md` — strict output specifications for all artifacts
- `references/HOOKS_GUIDE.md` — per-harness hook install, troubleshooting, portability notes
- `hooks/extract-state.sh` — pre-compact transcript parser (unix/bash, requires jq)
- `hooks/extract-state.ps1` — pre-compact transcript parser (Windows/PowerShell)
- `hooks/opencode.plugin.js` — opencode plugin (JS, SDK fetch, cross-platform, no shell)
- `hooks/pre-compact.sh` — marker-only fallback script (unix/bash)
- `hooks/pre-compact.ps1` — marker-only fallback script (Windows/PowerShell)
- `hooks/claude-code.hooks.json` — Claude Code hook config (unix)
- `hooks/claude-code.hooks.windows.json` — Claude Code hook config (Windows)
- `hooks/copilot.hooks.json` — Copilot hook config (unix + Windows fields)
- `examples/bootstrap-CONTEXT.md` — empty scaffold with markers for new CONTEXT.md files
- `examples/CONTEXT.md` — fully populated CONTEXT.md sample
- `examples/STATE.md` — sample session state file
- `examples/CHANGELOG.md` — changelog output examples
- `examples/SESSION-LOG.md` — session log entry examples