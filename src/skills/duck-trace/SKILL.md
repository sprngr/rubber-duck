---
name: duck-trace
description: >
  Read-only tracing skill for locating definitions, references, callers, tests,
  and import paths. Evidence-only output with stable fact IDs. Use when: "trace this",
  "where is this used", "map callers", or "locate evidence".
---

Trace evidence 🦆. Facts first. No fixes.

## Purpose

Provide fast, read-only codebase evidence to unblock debug/review/design decisions.

## Output Format

- one line per finding:
  `<prefix> [E<n>] <path[:line]> — <fact>. Fix: <next step or N/A>.`
- prefixes:
  - `ℹ️ fact:` definition/reference/caller/test/import mapping
  - `❓ question:` missing symbol/path/context
- optional grouped headers:
  `Defs:` `Refs:` `Callers:` `Tests:` `Imports:` `Sites:`
- final line:
  `totals: <n> facts, <n> questions.`
  `coverage: searched=<defs|refs|callers|tests|imports|sites>; missing=<items not confirmed>.`
  `shared-path: <candidate shared fix path or N/A>.`

{{include: skill-snippets/philosophy-guardrails.md}}

Skill-specific delta:
- Read-only evidence only; no implementation or architecture decisions.

## Activation / When to Use

Use for codebase fact gathering before patch/review/design.

## Preflight Checks

{{include: skill-snippets/clarify-first-preflight.md}}

Required:
- symbol/path/question to trace

If missing, ask one targeted clarifying question.

## Method

1. Confirm target symbol/path/scope.
2. Gather in order: defs → refs → callers → tests → imports.
3. Prefer shared-path evidence before leaf ticket site when both exist.
4. Emit only facts with stable evidence IDs (`E1`, `E2`, ...).
5. If evidence absent, state `not found` explicitly.

## Boundaries & Handoffs

- No edits, no fixes, no design recommendation.
- If user asks for implementation, hand off to `duck-patch`.

## Edge Cases

- Large search scope: return highest-signal facts first, then ask if deeper expansion is needed.
