---
name: duck-simplify
description: >
  Complexity reduction and semantic duplication/divergence review. Identifies unnecessary
  abstractions, oversized config/state surfaces, directness opportunities, safe extraction boundaries.
  Modes: standard (complexity reduction), dry (DRY/divergence).
  Use when: "simplify this", "is this overengineered", "DRY this",
  "divergence review".
license: MIT
metadata:
  author: sprngr
  version: v2.0.0
  RUBBER_DUCK_VERSION: v2.1.0
---

Simplify 🦆. Smaller shape, same behavior. Prevent divergence, not just repetition.

## Purpose

Find highest-value simplifications without weakening security, correctness, or explicit requirements.

## Philosophy Guardrails (skill-local)

Inherit shared guardrails from `references/GUARDRAILS.md`.

Skill-specific delta:

- Complexity-reduction guidance only; final implementation decisions remain with user.

## Activation

Use for complexity-minimization lens in review/design/debug contexts, including semantic duplication/divergence review.

## Method

### 1. Clarify scope (if unclear)

- ask 1-3 targeted clarifying questions when context is incomplete
- state assumptions explicitly when evidence is missing

Required:

- code/proposal scope

Dry-mode required:

- two or more candidate scopes with suspected semantic duplication

Optional:

- constraints (deadline, readability norms, team preference)

If constraints unclear, ask one targeted clarifying question.

### 2. Review for simplification

1. Identify complexity hotspots (layers, branches, config surface, indirection).
2. Verify evidence (callers, branch count, config usage) before recommendation.
3. Emit max 3 highest-impact simplifications.
4. Prefer deletion/reuse/stdlib/native before new abstraction.
5. For DRY-mode: confirm semantic duplication (not syntax-only), include `Diverges when` + `Extract start`, and prefer smallest safe extraction boundary.
6. If simplification would weaken trust boundaries/accessibility/explicit requirements, refuse and suggest safe alternative.
7. Do not flag tiny repetition that improves readability or low-risk literals/constants.

### 3. Output findings

**Standard mode:**

One line per finding:

`<prefix> <path[:line|scope]> — <complexity cost>. Fix: <smaller shape>.`

Prefixes:

- `🪶 yagni:` abstraction/config not justified yet
- `📚 stdlib:` custom code replaceable by standard library
- `🧱 native:` dependency/custom layer replaceable by platform feature
- `✂️ shrink:` same behavior in fewer lines
- `🗑️ delete:` dead/speculative code removable with no replacement
- `❓ question:` missing intent blocks judgment

Final line:

`totals: <n> findings, <n> questions.`
`net: -<N> lines possible.`

**Dry mode (DRY/dedupe/divergence-focused):**

One line per finding:

`<prefix> <path[:line|scopeA<->scopeB]> — <duplicated behavior + drift risk>. Diverges when: <future change trigger>. Extract start: <path:line>. Fix: <extraction boundary>.`

Dry-mode prefixes:

- `🟡 risk:` meaningful duplication likely to diverge
- `🔵 nit:` minor duplication worth cleanup
- `❓ question:` missing context blocks extraction choice

Dry-mode final line:

`totals: <n> findings, <n> questions.`
`coverage: semantic-dup=<checked|partial|missing>; extraction-start=<provided|missing>.`

## Boundaries

- No security/rollback severity ownership (`duck-risk`/`duck-review`).
- No test-gap ownership (`duck-triage`).
- No final PR-thread formatting ownership (`duck-review`).
