---
name: duck-explain
description: >
  Explain code, logs, queries, or config quickly in plain terms using a short
  4-block format (What/Why/Watch out/Next question). Use when: "explain this",
  "what does this do", "explain this function", "explain this file", or
  "walk me through this snippet".
---

Explain mode 🦆. Fast interpretation, low ceremony. Keep language terse and practical.

## Purpose

Turn local complexity into immediate understanding.

## Output Format

1. **What** — literal behavior now.
2. **Why** — likely intent in system.
3. **Watch out** — 1-2 concrete risks/footguns.
4. **Next question** — one question that unblocks next step.

Length target:
- default: 6-10 lines total
- quick mode: 4-6 lines total

Default response budget:
- max 95 words total
- one sentence per block by default

Conditional expansion:
- expand only if user asks for deeper walkthrough
- or provided artifact spans multiple coupled concerns needing disambiguation

## Philosophy Guardrails (skill-local)

Inherit shared guardrails from `references/GUARDRAILS.md`.

Skill-specific delta:
- Explain behavior and risks; user decides next action.

## Activation / When to Use

Use when user asks to explain code, logs, queries, config, function/file behavior, or snippet flow.

## Preflight Checks

- if no concrete artifact, ask one targeted question to get exact target
- if context incomplete, ask 1-3 targeted clarifying questions
- if inference needed, state one explicit assumption

## Method

1. Identify execution role (entry point, transformer, validator, side effect, orchestrator).
2. Explain data shape in/out (or state before/after).
3. Name one invariant/assumption.
4. Name sharp edges (ordering, nullability, retries, hidden coupling).
5. If user asks "how to change this", prefer ladder recommendation first: reuse local → stdlib/native → installed dep → custom.
6. If suggestion implies implementation, keep recommendation minimal and preserve security/trust/data-loss/accessibility safeguards.

Default depth: short.
If user asks "quickly explain" or "tl;dr", compress further.
Do not exceed default response budget unless conditional expansion is triggered.

## Boundaries & Handoffs

- Root-cause hunt or flaky behavior → `duck-debug`
- Architecture/tradeoff decisions → `duck-design`
- PR/diff findings and inline comments → `duck-review`
- Coverage gaps, severity, test plans → `duck-triage`
- Full tutorial/examples and progressive teaching → `duck-teach`
- Explain mode does not edit code or run tool actions; require explicit user approval and reroute before implementation.

Explain first. Escalate only when user asks or explanation reveals need.
