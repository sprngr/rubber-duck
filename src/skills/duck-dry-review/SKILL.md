---
name: duck-dry-review
description: >
  Semantic duplication review skill focused on divergence risk and safe extraction
  boundaries. Flags duplicated behavior likely to drift; ignores low-value repetition.
  Use when: "DRY this", "duplication risk", "dedupe", or "divergence review".
---

DRY review 🦆. Prevent divergence, not just repetition.

## Purpose

Identify meaningful semantic duplication and propose smallest safe extraction boundaries.

## Output Format

- one line per finding:
  `<prefix> <path[:line|scopeA<->scopeB]> — <duplicated behavior + drift risk>. Diverges when: <future change trigger>. Extract start: <path:line>. Fix: <extraction boundary>.`
- prefixes:
  - `🟡 risk:` meaningful duplication likely to diverge
  - `🔵 nit:` minor duplication worth cleanup
  - `❓ question:` missing context blocks extraction choice
- final line:
  `totals: <n> findings, <n> questions.`
  `coverage: semantic-dup=<checked|partial|missing>; extraction-start=<provided|missing>.`

{{include: skill-snippets/philosophy-guardrails.md}}

Skill-specific delta:
- Duplication/divergence guidance only; final implementation decisions remain with user.

## Activation / When to Use

Use for semantic duplication/divergence lens during review/design.

## Preflight Checks

{{include: skill-snippets/clarify-first-preflight.md}}

Required:
- two or more candidate scopes with suspected semantic duplication

Optional:
- expected future change triggers
- shared invariant hints

If extraction boundary unclear, ask one targeted clarifying question.

## Method

1. Confirm duplicated semantics (not just syntax similarity).
2. Prioritize repeated business rules, validation/error mapping, condition trees, transform pipelines.
3. Emit max 3 highest-impact findings.
4. Include `Diverges when` + `Extract start` in each finding.
5. Prefer smallest extraction boundary that reduces concrete divergence risk.

## Boundaries & Handoffs

- No security/correctness severity ownership (`duck-risk`/`duck-review`).
- No general simplification ownership (`duck-simplify`).
- No final PR-thread formatting ownership (`duck-review`).

## Edge Cases

- Do not flag tiny repetition that improves readability or low-risk literals/constants.
