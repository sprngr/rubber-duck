---
name: duck-tape
description: >
  Two-tier session memory: compact into CONTEXT.md (persistent) and
  .duck-tape/<id>.state.md (working). Merge/dedupe fixed-schema sections,
  append-only Notes, bootstrap from session content. Replaces handoff skill.
  Use when: "/duck-tape", "compact session", "update CONTEXT.md",
  "persist memory", "save session state", "checkpoint session".
---

Session memory management 🦆📼. Context hygiene, persistent memory, session state handoff.

## Purpose

Two-tier memory management for active sessions.

- **Tier 1 (persistent):** `CONTEXT.md` in cwd. Long-term, repo-tracked. 8 fixed sections, deterministic merge.
- **Tier 2 (working):** `.duck-tape/<session_id>.state.md`. Short-term, not committed. Agent State schema. Staging input for CONTEXT.md merge.

Preserve fidelity, keep interruption low.

## Philosophy Guardrails (skill-local)

Inherit shared guardrails from `references/GUARDRAILS.md`.
- ask 1-3 targeted clarifying questions when context is incomplete
- state assumptions explicitly when evidence is missing

Skill-specific delta:
- Persistent artifact safety: CONTEXT.md is long-lived and likely committed. Redaction is non-negotiable before any write.
- Session state safety: `.duck-tape/<id>.state.md` is workspace-local but may be read by next agent. Redaction applies.
- Rotation cap: max 10 state files in `.duck-tape/`. Oldest rotated out.
- Standing-approval via `.duck-tape/auto` marker file covers auto-compact state writes and merges only. Manual runs require per-run approval.

## Activation

**State-only** (default): write session state file. Signals: `/duck-tape`, "save session state", "checkpoint session".

**Merge** (CONTEXT.md): write state file plus merge into CONTEXT.md. Signals: "compact session", "update CONTEXT.md", "persist memory", `/duck-tape merge`.

Auto-compact threshold triggers merge mode.

## Method

### 1. Redact incoming content

Scan session content for secrets/PII: API keys, passwords, tokens, connection strings, env var values, personally identifiable information. On detection: reject flagged content, report findings, ask user to redact source or confirm mask-in-place (`<REDACTED>`). Never write raw secrets. Applies to both tiers.

### 2. Write session state file

Write `.duck-tape/<session_id>.state.md` using Agent State schema. Session ID format: `<YYYY-MM-DD-HHMM>`. Full schema in `references/STATE_SCHEMA.md`. Output format in `references/OUTPUT_SCHEMA.md`. Sample in `examples/STATE.md`. Auto-create `.duck-tape/.gitignore` with `*` content if missing.

Apply rotation cap: max 10 state files. Drop oldest if exceeded. Note dropped ID in Session-Log.

Report state file path: `.duck-tape/<session_id>.state.md` — user can use this to reload session state later.

### 3. Merge into CONTEXT.md (conditional)

Run only on merge signals. Skip for state-only mode.

**Bootstrap** (CONTEXT.md missing): create CONTEXT.md with translated content from state file using rigid map in `references/STATE_SCHEMA.md`. Empty sections get scaffold from `examples/bootstrap-CONTEXT.md`. Output format in `references/OUTPUT_SCHEMA.md`. Sample in `examples/CONTEXT.md`. Never infer Goals or Conventions entries.

**Merge** (CONTEXT.md exists): translate from session state file using rigid map. Per-section merge rules in `references/SCHEMA.md`. Summary:
- Goals/Decisions/Conventions/Glossary: dedupe by key, supersede on conflict, append new
- Deferred-Debt: append-only with status markers
- Open-Questions: append new, dedupe by text
- Session-Log: append timestamped entry, cap at 50, rotate oldest
- Notes: timestamped append-only, no rewrite, Re-derivation verbatim under `### Re-derivation <id>`

Emit changelog per `references/OUTPUT_SCHEMA.md`. Sample in `examples/CHANGELOG.md`:
- `Added: <section> <key>`
- `Superseded: <section> <key> (<old> -> <new>)`
- `Dropped: <section> <key> (<reason>)`

Drops require explicit reason. No silent removal.

### 4. Execution approval

**Workspace-changing actions** (require approval based on change type):

**Semantic changes** (require full execution approval):
- Code/logic changes
- Config/schema changes (settings, env vars, build config)
- Dependency changes (package.json, requirements.txt, etc.)
- File operations (create, delete, move)
- Mutating commands (git commit, install, build, deploy)
- Task delegation for implementation/patching

**Cosmetic changes** (require lightweight confirmation):
- Documentation edits (README, markdown files, standalone doc comments)
- Formatting/whitespace-only changes
- Typo fixes in non-code text files
- Confirmation phrase: "Confirm to proceed with [doc/formatting] change?"

**Edge cases:**
- JSDoc/docstring changes in code files -> semantic (affects generated docs, code contracts)
- Comments explaining logic in code -> semantic (affects maintainability understanding)
- Config comments -> semantic (affects interpretation)
- Document updates (ADRs, CONTEXT.md) -> semantic
- Examples in README that are code snippets -> semantic (users copy-paste)

**Approval workflow:**
Before any semantic change, require execution approval:
  1. **Preflight** (if missing, ask one clarifying question):
     - target files (bounded; max 2)
     - expected behavior change
     - smallest verification check
  2. **Present list of changes broken down by file**
  3. **Approval ask**: `Reply with "approve" to execute this scope.`
  4. **Wait for approval**: do not proceed with edits/commands/task delegation until user replies with approval

**Rules:**
- No workspace-changing action without user approval/confirmation
- If requested execution scope exceeds 2 files, split into smaller bounded tasks before executing
- If scope changes after approval, re-open approval before continuing


**Preflight per operation:**

State-only:
- Target files: `.duck-tape/<id>.state.md`, `.duck-tape/.gitignore` (if missing)
- Expected: write state file with Agent State schema
- Verification: re-read state file, confirm Agent State sections present

Merge:
- Target files: `.duck-tape/<id>.state.md`, `.duck-tape/.gitignore` (if missing), `CONTEXT.md`
- Expected: write state file, merge translated state into CONTEXT.md per schema rules
- Verification: re-read both files, confirm changelog matches CONTEXT.md diff

Auto-compact skips per-write approval. Standing approval from `/duck-tape auto on` covers auto state writes and merges.

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
2. Identify which of 8 schema sections exist, which are missing.
3. Parse freeform content (blocks not under a schema `##` header).
4. Classify each freeform block into nearest schema section:
   - Goals: optimization targets, priorities, north-star statements
   - Decisions: approved/rejected choices, rationale, dated decisions
   - Conventions: naming rules, file layout, style, tooling choices
   - Glossary: term definitions, domain vocabulary, acronym expansions
   - Deferred-Debt: TODO/FIXME/HACK entries, deferred work
   - Open-Questions: unresolved questions, pending clarifications
   - Session-Log: timestamped entries, status updates, session notes
   - Notes: everything else, freeform observations
5. Propose restructure to user. Show mapping: existing block -> target section. Flag low-confidence placements. Leave unmatched blocks listed above schema.
6. Get approval. Execute restructure. Report what moved, what stayed above schema.

**Preflight:**
- Target file: `CONTEXT.md`
- Expected: classify freeform content into schema sections, append missing headers, preserve unmatched content above schema
- Verification: re-read CONTEXT.md, confirm all 8 headers present, confirm all original content accounted for (moved or left above schema)

## Auto-compact opt-in

- `/duck-tape auto on` — grants standing approval for auto state writes and merges at token threshold. Writes `.duck-tape/auto` marker file.
- `/duck-tape auto off` — revokes. Removes marker file.
- On auto-compact fire: state write plus merge run with no per-write approval. Reply carries post-merge summary and prune direction.

## Boundaries

- Default mode is state-only. CONTEXT.md is written only on merge signals.
- Write only `CONTEXT.md`, `.duck-tape/<id>.state.md`, `.duck-tape/.gitignore`, `.duck-tape/auto` marker.
- Respect existing CONTEXT.md structure. If file lacks schema sections, prompt user to migrate before first merge.
- Never infer Goals or Conventions entries on bootstrap.
- Never fuzzy-rewrite Notes. Append-only at write time.
- Never silently drop entries. Changelog with reason required.
- Standing-approval via `.duck-tape/auto` is a skill-local extension to approval-gate-spec. Covers auto state writes and merges only.
