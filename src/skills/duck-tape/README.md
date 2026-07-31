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

### `/duck-tape auto on` — Enable auto-compact

Grants standing approval for automatic state writes and merges at token threshold. Writes `.duck-tape/auto` marker file.

### `/duck-tape auto off` — Disable auto-compact

Removes marker file. Revokes standing approval.

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

## Auto-Compact

When enabled, duck-tape automatically writes state and merges into CONTEXT.md when session token usage crosses a threshold. This prevents context loss on long sessions.

**Tradeoff:** auto-compact merges everything. Review CONTEXT.md periodically with `/duck-tape prune` to keep it tight.

## Security

Redaction runs before every write. Secrets, API keys, tokens, passwords, and PII are detected and blocked. You must confirm masking (`<REDACTED>`) before any flagged content reaches persistent storage.

Redaction applies to both tiers (CONTEXT.md and state files).

## Troubleshooting

**CONTEXT.md lacks schema sections.** Run `/duck-tape migrate` to classify existing content and append missing headers.

**State files accumulating.** Check rotation cap (max 10). Oldest files drop automatically. If you need to recover a dropped state, check CONTEXT.md Session-Log for the dropped ID.

**Merge produced unexpected entries.** Check the changelog. Each addition, supersession, and drop is logged with a reason. Use `/duck-tape prune` to clean Notes if needed.

**Auto-compact merging too aggressively.** Run `/duck-tape auto off` to disable. Merge manually only when you want CONTEXT.md updated.

## File Layout

```
<project>/
  CONTEXT.md                    — Tier 1 persistent memory
  .duck-tape/
    .gitignore                  — `*` (auto-created)
    <YYYY-MM-DD-HHMM>.state.md  — Tier 2 working state
    auto                        — auto-compact marker (if enabled)
```

## Troubleshooting

**CONTEXT.md lacks schema sections.** Run `/duck-tape migrate` to classify existing content and append missing headers.

**State files accumulating.** Check rotation cap (max 10). Oldest files drop automatically. Check CONTEXT.md Session-Log for dropped IDs.

**Merge produced unexpected entries.** Check the changelog. Each addition, supersession, and drop is logged with a reason. Use `/duck-tape prune` to clean Notes if needed.

**Auto-compact merging too aggressively.** Run `/duck-tape auto off` to disable. Merge manually only when you want CONTEXT.md updated.

## References

- `references/SCHEMA.md` — full CONTEXT.md schema definitions and merge rules
- `references/STATE_SCHEMA.md` — Agent State schema and translation map
- `references/OUTPUT_SCHEMA.md` — strict output specifications for all artifacts
- `examples/bootstrap-CONTEXT.md` — empty scaffold with markers for new CONTEXT.md files
- `examples/CONTEXT.md` — fully populated CONTEXT.md sample
- `examples/STATE.md` — sample session state file
- `examples/CHANGELOG.md` — changelog output examples
- `examples/SESSION-LOG.md` — session log entry examples