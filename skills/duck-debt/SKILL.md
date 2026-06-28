---
name: duck-debt
description: >
  Harvest every `duck-debt:` marker into a shortcut ledger so deferred
  simplifications stay visible. Read-only report. Use when:
  "duck debt", "what did we defer", "list duck shortcuts",
  "show simplification debt", or "/duck-debt".
---

Duck debt ledger 🦆. Collect deferred simplifications. Caveman mode always on.

## Marker Convention

Use marker in code comments:

`duck-debt: <ceiling>, upgrade when <trigger>`

Examples:
- `duck-debt: O(n²) scan, upgrade when list >10k`
- `duck-debt: global lock, upgrade when throughput contention observed`

## Scan

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

## Boundaries

- Read/report only. No edits.
- No debt-priority roadmap unless user asks.
- If asked to apply cleanup directly, route to `duck-review` (findings) then `duck-builder` (bounded patch).
