---
name: duck-debt
description: >
  Harvest every `duck-debt:` marker into a shortcut ledger so deferred
  simplifications stay visible. Read-only report. Use when:
  "duck debt", "what did we defer", "list duck shortcuts",
  "show simplification debt", or "/duck-debt".
---

Duck debt ledger 🦆. Collect deferred simplifications. Keep language terse and practical.

## Purpose

Collect deferred simplification markers into a read-only ledger.

## Philosophy Guardrails (skill-local)

- Decision ownership: user decides debt cleanup actions; this skill reports current debt markers.
- Ask-before-act: ask one clarifying question if scan scope is ambiguous.
- Evidence-first: report only markers actually found in repository scan output.
- Bounded approval: read/report only; no edits or execution of cleanup actions.
- Safety carve-outs: never recommend debt cleanup that weakens trust-boundary validation, security controls, data-loss prevention, accessibility requirements, or explicit user requirements.

## Activation / When to Use

Use when user asks for deferred simplification inventory (`duck debt`, `/duck-debt`, etc.).

## Preflight Checks

- if repository/module scope ambiguous, ask one clarifying question before scanning

## Method

### Marker Convention

Use marker in code comments:

`duck-debt: <ceiling>, upgrade when <trigger>`

Examples:
- `duck-debt: O(n²) scan, upgrade when list >10k`
- `duck-debt: global lock, upgrade when throughput contention observed`

### Scan

Search repo for comment markers:
- `duck-debt:`

Ignore generated/vendor paths (`node_modules`, `.git`, build outputs).

## Output

Group by file. One line per marker:

`<file>:<line> — <shortcut>. ceiling: <ceiling>. upgrade: <trigger>.`

If marker missing trigger, add tag:

`no-trigger`

Final line:

`totals: <N> markers, <M> no-trigger.`

No markers:

`No duck-debt markers. Clean ledger.`

## Boundaries & Handoffs

- Read/report only. No edits.
- No debt-priority roadmap unless user asks.
- If asked to apply cleanup directly, route to `duck-review` (findings) then `duck-builder` (bounded patch).
- Do not recommend debt cleanup paths that weaken trust-boundary validation, security controls, data-loss prevention, accessibility requirements, or explicit user requirements.
- If user asks for cleanup planning, prefer smallest safe follow-up path first.

## Edge Cases

- missing trigger text: emit `no-trigger` tag
- no markers found: output clean-ledger line only
