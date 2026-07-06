---
name: duck-debt
description: >
  Build a read-only deferred-work ledger from TODO/FIXME/HACK/XXX comments.
  Broad mode is default; strict mode returns only issue-linked entries.
  Use when users ask to audit deferred work (e.g., "duck debt",
  "what did we defer", "/duck-debt").
---

Duck debt ledger 🦆. Audit deferred work. Keep language terse and practical.

## Purpose

Build a read-only ledger of deferred-work entries from common comment conventions.

## Activation / When to Use

Use when users ask for deferred-work inventory (for example: `duck debt`, `what did we defer`, `/duck-debt`).

Strict branch trigger:
- use strict mode when users ask for “issue-linked only” or “strict”

## Preflight Checks

- ask 1-3 targeted clarifying questions when context is incomplete
- state assumptions explicitly when evidence is missing
- Debt-specific override: if repository/module scope is ambiguous, ask exactly one clarifying question before scanning
- inherit shared guardrails from `references/GUARDRAILS.md`

Mode default rule (hard):
- default to broad mode unless users explicitly ask for strict mode

Ambiguous scope rule (hard):
- if prompt does not specify repository/path scope, ask exactly one concise clarifying question first
- example ambiguous prompt: "Show me all deferred simplification debt."
- do not claim completed extraction before scope is confirmed
- stop after the clarification question until user answers

## Output Contract

Group by file. One line per entry:

`<file>:<line> [<tier>] — <note>. ref: <issue|none>.`

Tiers:
- `explicit` — debt signal with issue ref
- `likely` — `FIXME` or `HACK` without issue ref
- `weak` — `TODO` or `XXX` without issue ref

Issue refs include patterns like `#123`, `ABC-123`, or URL.

Final line:

`totals: <N> entries (explicit: <E>, likely: <L>, weak: <W>).`

Strict mode (`strict`):

`totals: <N> entries (strict: issue-linked only).`

No entries:

`No deferred-work entries. Clean ledger.`

Scoped no-entries format:

`No deferred-work entries in <scope>. Clean ledger.`

## Philosophy Guardrails (skill-local)

Inherit shared guardrails from `references/GUARDRAILS.md`.

Skill-specific delta:
- Read/report only debt ledger; user decides cleanup actions.

## Method

### Signal Conventions (Broad Default)

Primary deferred-work signals in comments:

- `TODO`
- `FIXME`
- `HACK`
- `XXX`

Issue-link detection:
- `#<number>`
- `<PROJECT>-<number>` (for example `ENG-42`)
- issue URL

### Counting + Classification Rules (hard)

- count only active deferred-work comment signals with concrete deferred work content
- count deferred-work signals in code and docs artifacts (including ADR/policy/runbooks) as active entries by default
- treat only obvious teaching/reference samples as non-active (for example fenced examples labeled "example", "template", or "sample")
- if scope contains only mentions/examples and no active entries, report scoped zero findings
- classify tiers as:
  - `explicit` — signal includes issue link
  - `likely` — `FIXME` or `HACK` without issue link
  - `weak` — `TODO` or `XXX` without issue link
- in strict mode, include only `explicit` entries

### Scan

Search repo for deferred-work comment signals:
- `TODO|FIXME|HACK|XXX`

Ignore generated/vendor paths (`node_modules`, `.git`, build outputs).

Scoped reporting rule:
- when user supplies scope (example: `docs/`), explicitly echo scope in output header or no-entries line

### Classification Validation Loop (for ambiguous entries)

For borderline matches, run this loop before final classification:
1) Confirm context: code comment vs docs/examples/templates/meta-text.
2) Confirm actionability: concrete deferred work exists (not informational note only).
3) Confirm reference signal: issue-linked or not.
4) Assign tier: `explicit` if issue-linked, else `likely` for `FIXME/HACK`, else `weak` for `TODO/XXX`; drop non-active references.

If uncertainty remains after loop, classify conservatively (`weak`) and add one short uncertainty note.

### Dual-reporting Rule

- when user asks to list every `TODO/FIXME/HACK/XXX` occurrence, report two labeled groups:
  1) `active deferred-work entries`
  2) `reference occurrences`
- keep reference occurrences explicitly labeled non-active
- for scoped zero findings, use: `No deferred-work entries in <scope>. Clean ledger.`

## Edge Cases

- missing issue ref in broad mode: keep entry and tier as `likely`/`weak`
- strict mode with no issue-linked entries: output clean-ledger line only
- deferred-work markers in docs/ADR/policy are active entries by default
- only explicit examples/templates/samples are non-active reference occurrences unless user asks for all occurrences

## Boundaries & Handoffs

- Read/report only. No edits.
- No debt-priority roadmap unless user asks.
- If asked to apply cleanup directly, route to `duck-review` (findings) then `duck-builder` (bounded patch).
- Do not recommend debt cleanup paths that weaken core safeguards:
- never weaken trust-boundary validation, security controls, data-loss prevention, accessibility requirements, or explicit user requirements

- If user asks for cleanup planning, prefer smallest safe follow-up path first.

## Examples

- `// TODO: simplify parser once telemetry confirms final format`
- `# FIXME: retry policy duplicates client defaults (#123)`
- `// HACK: temporary bypass for legacy payload, remove after ENG-42`
