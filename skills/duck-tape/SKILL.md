---
name: duck-tape
description: >
  Two-tier session memory: compact into CONTEXT.md (persistent) and
  .duck-tape/<id>.state.md (working). Merge/dedupe fixed-schema sections,
  append-only Notes, bootstrap from session content. Subcommands: merge,
  resume, init, prune, migrate.
  Use when: "duck-tape", "compact session", "update CONTEXT.md",
  "resume session".
license: MIT
metadata:
  author: sprngr
  version: v2.1.0
  RUBBER_DUCK_VERSION: v2.1.0
---

Session memory management 🦆📼. Context hygiene, persistent memory, session state handoff.

## Purpose

Two-tier memory management for active sessions.

- **Tier 1 (persistent):** `CONTEXT.md` in cwd. Long-term, repo-tracked. 7 fixed sections, deterministic merge.
- **Tier 2 (working):** `.duck-tape/<session_id>.state.md`. Short-term, not committed. Agent State schema. Staging input for CONTEXT.md merge.

Preserve fidelity, keep interruption low.

## Philosophy Guardrails (skill-local)

Inherit shared guardrails from `references/GUARDRAILS.md`.
- ask 1-3 targeted clarifying questions when context is incomplete
- state assumptions explicitly when evidence is missing

Skill-specific delta:

- Persistent artifact safety: CONTEXT.md is long-lived and likely committed. Redaction is non-negotiable before any write.
- Session state safety: `.duck-tape/<id>.state.md` is workspace-local but may be read by next agent. Redaction applies.
- Rotation cap: max 10 state files in `.duck-tape/`. Eviction precedence: auto dropped first, then recovered, then manual.
- Pre-compact marker (`.duck-tape/.last-compact`) is harness-written, non-semantic. No approval required for marker write.

## Activation

**State-only** (default): write session state file. Signals: `/duck-tape`, "save session state", "checkpoint session".

**Merge** (CONTEXT.md): write state file plus merge into CONTEXT.md. Signals: "compact session", "update CONTEXT.md", "persist memory", `/duck-tape merge`.

**Resume**: detect compaction and reload checkpoint. Signals: `/duck-tape resume`, "resume session". Read-only when manual checkpoint exists. If only auto-checkpoint or no state file, invokes LLM-assisted recovery that writes `-recovered.state.md` (approval required).

## Method

### 1. Redact incoming content

Scan session content for secrets/PII: API keys, passwords, tokens, connection strings, env var values, personally identifiable information. On detection: reject flagged content, report findings, ask user to redact source or confirm mask-in-place (`<REDACTED>`). Never write raw secrets. Applies to both tiers.

### 2. Write session state file

Write `.duck-tape/<session_id>.state.md` using Agent State schema. Session ID format: `<YYYY-MM-DD-HHMM>`. Full schema in `references/STATE_SCHEMA.md`. Output format in `references/OUTPUT_SCHEMA.md`. Sample in `examples/STATE.md`. Auto-create `.duck-tape/.gitignore` with `*` content if missing.

Session ID handling:
- Default: auto-generate `<YYYY-MM-DD-HHMM>` silently for `/duck-tape` and `/duck-tape merge`.
- Ask for session ID only when user explicitly requests a custom ID.
- If custom ID is provided and invalid, ask one corrective question with required format, then continue.

Apply rotation cap: max 10 state files. Eviction precedence: auto dropped first (oldest auto), then recovered, then manual.

Report state file path: `.duck-tape/<session_id>.state.md` — user can use this to reload session state later.

### 3. Merge into CONTEXT.md (conditional)

Run only on merge signals. Skip for state-only mode.

**Bootstrap** (CONTEXT.md missing): create CONTEXT.md with translated content from state file using rigid map in `references/STATE_SCHEMA.md`. Empty sections get scaffold from `examples/bootstrap-CONTEXT.md`. Generate TOC under title from the 8 section headers. Output format in `references/OUTPUT_SCHEMA.md`. Sample in `examples/CONTEXT.md`. Never infer Goals or Conventions entries.

**Merge** (CONTEXT.md exists): translate from session state file using rigid map. Summarize translated content to persistent-context granularity (decision-level, not commit-level) before applying per-section merge rules. Refresh TOC only if the set of `##` section headings changes. Per-section merge rules in `references/SCHEMA.md`. Summary:

- Goals/Decisions/Conventions/Glossary: dedupe by key, supersede on conflict, append new
- Deferred-Debt: append-only with status markers
- Open-Questions: append new, dedupe by text
- Notes: timestamped append-only, no rewrite.
- Re-derivation + Suggested Skills: state-file-local, not translated to CONTEXT.md
- Position.Current + Position.Done: state-file-local, not translated. Next agent reads state file on resume.

Emit changelog per `references/OUTPUT_SCHEMA.md`. Sample in `examples/CHANGELOG.md`:

- `Added: <section> <key>`
- `Superseded: <section> <key> (<old> -> <new>)`
- `Dropped: <section> <key> (<reason>)`

Drops require explicit reason. No silent removal.

### 4. Execution approval

**Workspace-changing actions** (require approval based on change type):

**Semantic changes** (require full execution approval):

- Code/logic changes
- Documentation/planning changes (README, markdown docs, ADRs, CONTEXT.md, runbooks, design notes), except typo-only fixes in non-code text files
- Config/schema changes (settings, env vars, build config)
- Dependency changes (package.json, requirements.txt, etc.)
- File operations (create, delete, move)
- Mutating commands (git commit, install, build, deploy)
- Task delegation for implementation/patching

**Cosmetic changes** (require lightweight confirmation):

- Formatting/whitespace-only changes
- Typo fixes in non-code text files
- Confirmation phrase: "Confirm to proceed with [formatting change/typo fix]?"

**Edge cases:**

- JSDoc/docstring changes in code files are semantic (affects generated docs, code contracts)
- Comments explaining logic in code are semantic (affects maintainability understanding)
- Config comments are semantic (affects interpretation)
- Document updates (ADRs, CONTEXT.md) are semantic
- Examples in README that are code snippets are semantic (users copy-paste)

**Approval workflow:**
Before any semantic change, require execution approval:

  1. **Preflight** (if missing, ask one clarifying question):
     - target phase:
       - Phase 1: stubs/skeleton/interfaces
       - Phase 2: wiring/integration
       - Phase 3: concrete implementation
     - phase-fit statement (why this diff matches phase constraints)
     - target files (bounded for selected phase)
     - expected behavior change
     - smallest verification check
  2. **Present list of changes broken down by file as formatted diff**
     - File exists: unified diff (`---`/`+++`/`@@` hunks, `-`/`+` prefixes)
     - File does not exist: full content in fenced code block, file path as header
     - One file per diff block
     - If any file violates phase constraints, split and re-propose before approval ask
  3. **Approval ask**: `Approve this scope? (examples: approve/ok/confirm)`
  4. **Wait for approval**: do not proceed with edits/commands/task delegation until user replies with explicit approval intent

**Rules:**

- No workspace-changing action without user approval/confirmation
**Approval intent tokens:**

- Accept as approval intent: "approve", "approved", "ok", "go ahead", "confirm", "yes"
- Examples are non-exhaustive. Any clear approval intent is accepted.
- Do not treat non-approval continuation signals (for example: "continue", "B") as approval

**Scope rules:**

- Phase caps (default):
  - Phase 1 (stubs/skeleton/interfaces): up to 6 files
  - Phase 2 (wiring/integration): up to 4 files
  - Phase 3 (concrete implementation): up to 2 files

- **Phase content constraints (hard gate):**
  - **Phase 1 (stubs/skeleton/interfaces) must contain only:**
    - file/module skeleton shape (folders, exports, section layout)
    - type/interface declarations
    - function/class signatures
    - placeholder returns/errors/TODO markers
    - minimal no-op wiring with no business logic
  - **Phase 1 must not contain:**
    - full feature/business logic
    - side-effectful flows (DB/network/auth/file writes)
    - complete UI behavior beyond placeholders
  - **Phase 2 (wiring/integration) can contain:**
    - route registration, DI/container wiring, module composition, event hookups
    - adaptation glue between existing components
  - **Phase 2 must not contain:**
    - substantial new business logic blocks
  - **Phase 3 (concrete implementation) contains:**
    - business logic, algorithms, side effects, full behavior completion

- **New-file bootstrap rule:**
  - If scope introduces new feature files, first approval pass must be Phase 1 stubs/skeleton/interfaces only.
  - Implement bodies in later Phase 2/3 approvals.
  - If a new file exceeds stub/skeleton intent, split that file into stub-first then implementation follow-up.
- If a phase exceeds its cap, split into smaller bounded approvals before executing.
- Review-fatigue triggers (objective):
  - Phase 1 (stubs/skeleton/interfaces):
    - If proposed diff in one approval exceeds 180 changed lines (additions + deletions) total, reduce current phase cap by at least 1 file (minimum cap is 1 file).
    - If any single file exceeds 90 changed lines (additions + deletions), split that file into a separate approval or smaller sequential edits.
  - Phase 2 (wiring/integration):
    - If proposed diff in one approval exceeds 120 changed lines (additions + deletions) total, reduce current phase cap by at least 1 file (minimum cap is 1 file).
    - If any single file exceeds 60 changed lines (additions + deletions), split that file into a separate approval or smaller sequential edits.
  - Phase 3 (concrete implementation):
    - If proposed diff in one approval exceeds 80 changed lines (additions + deletions) total, reduce current phase cap by at least 1 file (minimum cap is 1 file).
    - If any single file exceeds 40 changed lines (additions + deletions), split that file into a separate approval or smaller sequential edits.
  - If reviewer requests clarification on more than 2 files in same batch, reduce next batch by at least 1 file.
- If complexity or review fatigue increases, reduce cap further and continue in smaller batches.
- Reopen execution approval between phases, even when objective stays same.
- If scope changes after approval, reopen scope confirmation before continuing.

**Preflight per operation:**

State-only:

- Target files: `.duck-tape/<id>.state.md`, `.duck-tape/.gitignore` (if missing)
- Expected: write state file with Agent State schema
- Verification: re-read state file, confirm Agent State sections present

Merge:

- Target files: `.duck-tape/<id>.state.md`, `.duck-tape/.gitignore` (if missing), `CONTEXT.md`
- Expected: write state file, merge translated state into CONTEXT.md per schema rules
- Verification: re-read both files, confirm changelog matches CONTEXT.md diff

## Harness integration

Pre-compact trigger writes `.duck-tape/.last-compact` marker and `.duck-tape/<id>-auto.state.md` state file before context compaction. State file is auto-extracted from session transcript (Claude Code, Copilot) or fetched via SDK (opencode). Trigger runs as shell script or plugin outside LLM context.

Marker format: `<timestamp> | cwd: <path> | latest-state: <file> | transcript: <path>`. The `transcript` field records the source transcript path (Claude Code, Copilot) or opencode snapshot path (`<id>-transcript.json`). Absent in older markers written before Angle B.

State file (`<id>-auto.state.md`) contains auto-extracted Approved Workflow, Position (tool calls + last assistant text), and Decision Log (pattern-matched, deduped, last 10). Low-fidelity recovery fallback. Pattern matching catches explicit decisions (APPROVED/DECIDED/CHOSE) but misses implicit ones. Manual `/duck-tape` checkpoint produces higher-fidelity state. `/duck-tape resume` with LLM-assisted recovery (Angle B) produces `-recovered.state.md` with semantic decision extraction, between auto and manual in fidelity.

Trigger falls back to marker-only on failure: jq missing (bash), transcript missing, format unknown, nothing extracted, SDK error (opencode). `pre-compact.sh`/`.ps1` retained as marker-only fallback scripts.

**Resume from compaction:** see `## Resume` below. Triggered by `/duck-tape resume`, not automatic.

**Guided install:** see `## Init` section below. See `references/HOOKS_GUIDE.md` for manual install and troubleshooting.

**Portability:** trigger behavior identical across all three harnesses. No threshold detection. No context re-injection. State file + marker.

## Resume

`/duck-tape resume` — detect compaction and reload checkpoint.

1. Check `.duck-tape/.last-compact`. If missing, no compaction occurred. Report "no compaction marker found" and stop.
2. Compare marker timestamp to session start time. If marker older than session start, no compaction in this session. Report "no recent compaction" and stop.
3. If marker newer than session start, compaction occurred. Read marker fields: `cwd`, `latest-state`, `transcript` (transcript path or opencode snapshot path; absent in older markers).
4. Select state file by precedence: **manual > recovered > auto**.
   a. If a manual checkpoint (no suffix) exists and is newer than the newest auto-checkpoint, use manual. Report position from it. Skip to step 6.
   b. If only an auto-checkpoint (`-auto` suffix) exists or no state file exists at all, invoke LLM-assisted recovery (step 5).
5. **LLM-assisted recovery** (Angle B). Produces a higher-fidelity state file than the auto-checkpoint by semantic synthesis from transcript content.
   - Transcript path: marker `transcript` field if present. If absent, no recovery possible; report "compaction occurred but no transcript path in marker" and suggest running `/duck-tape` to checkpoint fresh.
   - Run `hooks/extract-raw.sh <transcript_path>` (bash) or `hooks/extract-raw.ps1 <transcript_path>` (PowerShell on Windows) to get raw material. Script outputs structured markdown: user prompts, tool calls, last 10 assistant messages, potential decisions (pattern-filtered, deduped), failed tool results, session metadata.
   - Read raw material output.
   - Synthesize Agent State file from raw material. Extract decisions semantically (not pattern-matched like Angle A): "we're going with option 2 because X" is a decision even without the keyword. Extract position (current/done/remaining) from assistant messages and tool calls. Extract established facts from tool results and user confirmations.
   - Write state file as `.duck-tape/<YYYY-MM-DD-HHMM>-recovered.state.md`.
   - Rotation: `-recovered` files share the 10-file cap with manual and auto. Precedence on eviction: auto dropped first, then recovered, then manual.
   - Report position from new file.
6. Read `CONTEXT.md` if it exists.
7. Report: compaction timestamp, session state position (Current/Done/Remaining), and any CONTEXT.md decisions relevant to current work.
8. State file writes (step 5 only) require approval. Read-only resume (steps 1-4, 6-7) does not write.

If no state file exists and no transcript path in marker, report "compaction occurred but no recoverable state" and suggest running `/duck-tape` to checkpoint fresh.

## Init

`/duck-tape init` — guided hook install. Opt-in.

1. Ask user which harness: opencode, Claude Code, or Copilot.
2. Based on choice, identify the correct hook config snippet:
   - opencode: `hooks/opencode.plugin.js`
   - Claude Code (unix): `hooks/claude-code.hooks.json`
   - Claude Code (Windows): `hooks/claude-code.hooks.windows.json`
   - Copilot: `hooks/copilot.hooks.json`
3. Show user the target install path for their harness:
   - opencode: `.opencode/plugins/duck-tape.js`
   - Claude Code: merge into `.claude/settings.json` under `hooks` key
   - Copilot: `.github/hooks/duck-tape.json`
4. Ask user if they want the skill to write the file or show the snippet for manual placement.
5. If write: confirm target path with user (approval required, file creation). Write file. Report success.
6. If show: print snippet and placement instructions. Point to `references/HOOKS_GUIDE.md` for troubleshooting.
7. Confirm `hooks/extract-state.sh` (unix) or `hooks/extract-state.ps1` (Windows) is in project. For opencode, no shell script needed (plugin fetches via SDK). Also confirm `hooks/extract-raw.sh`/`.ps1` exists for LLM-assisted recovery on `/duck-tape resume`.

**Preflight:**

- Target file: harness-specific config path (max 1 file)
- Expected: write hook config snippet to harness install path
- Verification: re-read written file, confirm valid JSON or JS syntax

## Prune

`/duck-tape prune` — manual. Targets Notes section only.

1. List Notes entries with timestamps.
2. User picks entries to cull.
3. Write culled file. Report what removed.

**Preflight:**

- Target file: `CONTEXT.md` (Notes section only)
- Expected: remove user-selected Notes entries, fixed-schema sections untouched
- Verification: re-read CONTEXT.md, confirm only Notes changed, confirm selected entries removed

Prune never touches fixed-schema sections.

## Migrate

`/duck-tape migrate` — restructures existing CONTEXT.md into schema. Classifies freeform content into sections, appends missing headers, leaves unmatched content above schema.

1. Read existing CONTEXT.md.
2. Identify which of 7 schema sections exist, which are missing.
3. Parse freeform content (blocks not under a schema `##` header).
4. Classify each freeform block into nearest schema section:
   - Goals: optimization targets, priorities, north-star statements
   - Decisions: approved/rejected choices, rationale, dated decisions
   - Conventions: naming rules, file layout, style, tooling choices
   - Glossary: term definitions, domain vocabulary, acronym expansions
   - Deferred-Debt: TODO/FIXME/HACK entries, deferred work
   - Open-Questions: unresolved questions, pending clarifications
   - Open-Questions: unresolved questions, pending clarifications
   - Notes: everything else, freeform observations
5. Propose restructure to user. Show mapping: existing block -> target section. Flag low-confidence placements. Leave unmatched blocks listed above schema.
6. Get approval. Execute restructure. Generate TOC under title from the 8 section headers. Report what moved, what stayed above schema.

**Preflight:**

- Target file: `CONTEXT.md`
- Expected: classify freeform content into schema sections, append missing headers, preserve unmatched content above schema
- Verification: re-read CONTEXT.md, confirm all 7 headers present, confirm all original content accounted for (moved or left above schema)

## Boundaries

- Default mode is state-only. CONTEXT.md is written only on merge signals.
- Write only `CONTEXT.md`, `.duck-tape/<id>.state.md`, `.duck-tape/<id>-recovered.state.md`, `.duck-tape/<id>-transcript.json`, `.duck-tape/.gitignore`, `.duck-tape/.last-compact` marker.
- Respect existing CONTEXT.md structure. If file lacks schema sections, prompt user to migrate before first merge.
- Never infer Goals or Conventions entries on bootstrap.
- Never fuzzy-rewrite Notes. Append-only at write time.
- Never silently drop entries. Changelog with reason required.
