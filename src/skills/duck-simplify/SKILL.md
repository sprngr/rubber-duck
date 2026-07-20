---
name: duck-simplify
description: >
  Canonical complexity-reduction skill covering simplification and semantic
  duplication/divergence review. Focuses on unnecessary abstractions, oversized
  config/state surfaces, directness opportunities, and safe extraction
  boundaries. Use when: "simplify this", "is this overengineered", "reduce
  complexity", "make this smaller", "DRY this", "dedupe", or "divergence review".
---

Simplify 🦆. Smaller shape, same behavior. Prevent divergence, not just repetition.

## Purpose

Find highest-value simplifications without weakening security, correctness, or explicit requirements.

## Output Format

- one line per finding:
  `<prefix> <path[:line|scope]> — <complexity cost>. Fix: <smaller shape>.`
- prefixes:
  - `🪶 yagni:` abstraction/config not justified yet
  - `📚 stdlib:` custom code replaceable by standard library
  - `🧱 native:` dependency/custom layer replaceable by platform feature
  - `✂️ shrink:` same behavior in fewer lines
  - `🗑️ delete:` dead/speculative code removable with no replacement
  - `❓ question:` missing intent blocks judgment
- final line:
  `totals: <n> findings, <n> questions.`
  `net: -<N> lines possible.`

Dry-mode finding shape (use when request is DRY/dedupe/divergence-focused):
- one line per finding:
  `<prefix> <path[:line|scopeA<->scopeB]> — <duplicated behavior + drift risk>. Diverges when: <future change trigger>. Extract start: <path:line>. Fix: <extraction boundary>.`
- dry-mode prefixes:
  - `🟡 risk:` meaningful duplication likely to diverge
  - `🔵 nit:` minor duplication worth cleanup
  - `❓ question:` missing context blocks extraction choice
- dry-mode final line:
  `totals: <n> findings, <n> questions.`
  `coverage: semantic-dup=<checked|partial|missing>; extraction-start=<provided|missing>.`

{{include: skill-snippets/philosophy-guardrails.md}}

Skill-specific delta:
- Complexity-reduction guidance only; final implementation decisions remain with user.

## Activation / When to Use

Use for complexity-minimization lens in review/design/debug contexts, including semantic duplication/divergence review.

## Preflight Checks

{{include: skill-snippets/clarify-first-preflight.md}}

Required:
- code/proposal scope

Dry-mode required:
- two or more candidate scopes with suspected semantic duplication

Optional:
- constraints (deadline, readability norms, team preference)

If constraints unclear, ask one targeted clarifying question.

## Method

1. Identify complexity hotspots (layers, branches, config surface, indirection).
2. Verify evidence (callers, branch count, config usage) before recommendation.
3. Emit max 3 highest-impact simplifications.
4. Prefer deletion/reuse/stdlib/native before new abstraction.
5. For DRY-mode: confirm semantic duplication (not syntax-only), include `Diverges when` + `Extract start`, and prefer smallest safe extraction boundary.

## Boundaries & Handoffs

- No security/rollback severity ownership (`duck-risk`/`duck-review`).
- No test-gap ownership (`duck-triage`).
- No final PR-thread formatting ownership (`duck-review`).

## Edge Cases

- If simplification would weaken trust boundaries/accessibility/explicit requirements, refuse and suggest safe alternative.
- Do not flag tiny repetition that improves readability or low-risk literals/constants.
