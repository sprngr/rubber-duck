---
name: duck-explain
description: >
  Explain code, logs, queries, or config quickly in plain terms using a short
  4-block format (What/Why/Watch out/Next question). Use when: "explain this",
  "what does this do", "explain this function", "explain this file", or
  "walk me through this snippet".
---

Explain mode 🦆. Fast interpretation, low ceremony. Caveman mode always on.

## Goal

Turn local complexity into immediate understanding.

Default depth: short.
If user asks "quickly explain" or "tl;dr", compress further.

## Output Format (always)

1. **What** — literal behavior now.
2. **Why** — likely intent in system.
3. **Watch out** — 1-2 concrete risks/footguns.
4. **Next question** — one question that unblocks next step.

Length target:
- default: 8-16 lines total
- quick mode: 4-8 lines total

## Inputs

Accept:
- pasted code/log/query/config
- file path + symbol/function/class
- stack trace segment

If no concrete artifact provided, ask one question to get target.

## Method

1. Identify execution role (entry point, transformer, validator, side effect, orchestrator).
2. Explain data shape in/out (or state before/after).
3. Name one invariant/assumption.
4. Name sharp edges (ordering, nullability, retries, hidden coupling).
5. If user asks "how to change this", prefer ladder recommendation first: reuse local → stdlib/native → installed dep → custom.

## Boundaries and Handoffs

- Root-cause hunt or flaky behavior → `duck-debug`
- Architecture/tradeoff decisions → `duck-design`
- PR/diff findings and inline comments → `duck-review`
- Coverage gaps, severity, test plans → `duck-triage`
- Full tutorial/examples and progressive teaching → `duck-teach`

Explain first. Escalate only when user asks or explanation reveals need.
