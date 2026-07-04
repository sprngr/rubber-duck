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

## Output

Group by file. One line per marker:

`<file>:<line> — <shortcut>. ceiling: <ceiling>. upgrade: <trigger>.`

If marker missing trigger, add tag:

`no-trigger`

Final line:

`totals: <N> markers, <M> no-trigger.`

No markers:

`No duck-debt markers. Clean ledger.`

Scoped no-markers format:

`No duck-debt markers in <scope>. Clean ledger.`

## Philosophy Guardrails (skill-local)

Inherit shared guardrails from `references/GUARDRAILS.md`.

Skill-specific delta:
- Read/report only debt ledger; user decides cleanup actions.

## Activation / When to Use

Use when user asks for deferred simplification inventory (`duck debt`, `/duck-debt`, etc.).

## Preflight Checks

- if repository/module scope ambiguous, ask one clarifying question before scanning

Ambiguous scope rule (hard):
- if prompt does not specify repository/path scope (for example: "Show me all deferred simplification debt."), ask exactly one concise clarifying question first
- do not claim completed extraction before scope is confirmed
- stop after the clarification question until user answers

## Method

Default/Recommended:
- Recommended default: report `active debt markers` first, then `reference occurrences` only when requested or when disambiguation is needed.

### Marker Convention

Use marker in code comments:

`duck-debt: <ceiling>, upgrade when <trigger>`

Counting rule (hard):
- count only active debt markers that match marker convention with concrete deferred debt content
- do not count plain mentions, docs references, examples, or meta-text that merely contains `duck-debt:` without an active deferred debt item
- if scope contains only mentions/examples and no active markers, report scoped zero findings

Dual-reporting rule:
- when user asks to list every `duck-debt:` marker occurrence, report two labeled groups:
  1) `active debt markers` (actionable deferred items)
  2) `reference occurrences` (mentions/examples/templates/non-active)
- keep reference occurrences explicitly labeled non-active so they are not mistaken for actionable debt
- for scoped audits that ask for zero findings behavior, prioritize active-marker result in final zero line (`No active duck-debt markers in <scope>. Clean ledger.`)

Examples:
- `duck-debt: O(n²) scan, upgrade when list >10k`
- `duck-debt: global lock, upgrade when throughput contention observed`

### Scan

Search repo for comment markers:
- `duck-debt:`

Ignore generated/vendor paths (`node_modules`, `.git`, build outputs).

Scoped reporting rule:
- when user supplies scope (example: `docs/`), explicitly echo scope in output header or no-markers line

## Boundaries & Handoffs

- Read/report only. No edits.
- No debt-priority roadmap unless user asks.
- If asked to apply cleanup directly, route to `duck-review` (findings) then `duck-builder` (bounded patch).
- Do not recommend debt cleanup paths that weaken trust-boundary validation, security controls, data-loss prevention, accessibility requirements, or explicit user requirements.
- If user asks for cleanup planning, prefer smallest safe follow-up path first.

## Edge Cases

- missing trigger text: emit `no-trigger` tag
- no markers found: output clean-ledger line only
