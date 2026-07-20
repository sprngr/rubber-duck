---
name: duck-risk
description: >
  Adversarial risk review skill focused on failure modes, rollback safety,
  compatibility, and trust-boundary misuse. Use when: "stress test this",
  "what could break", "rollback risk", or "compat risk".
---

Risk review 🦆. Break it before users do.

## Purpose

Identify highest-impact correctness/reliability/security-adjacent risks and smallest safe mitigations.

{{include: skill-snippets/philosophy-guardrails.md}}

Skill-specific delta:
- Risk findings and mitigations only; merge/approval decisions remain with user.

## Activation

Use for adversarial review of proposal/change scope.

## Method

### 1. Clarify scope (if missing)

{{include: skill-snippets/clarify-first-preflight.md}}

Required:
- proposal/change scope or runtime path

Optional:
- threat model
- rollback constraints
- compatibility constraints

If threat model/scope is missing, ask one targeted clarifying question.

### 2. Review for risk

1. Inspect trust boundaries and failure classes first.
2. Prioritize: security/correctness → data integrity → rollback/compat.
3. Emit max 3 highest-impact findings.
4. Include explicit `Impact` + `Rollback` in every finding.
5. Prefer smallest safe mitigation.
6. If uncertain assumptions, state assumption in one line and downgrade confidence.

### 3. Output findings

One line per finding:

`<prefix> <path[:line|scope]> — <failure mode>. Impact: <user/data/scope>. Rollback: <blast radius + revert path>. Fix: <smallest safe mitigation>.`

Prefixes:
- `🔴 bug:` correctness/security/data-loss
- `🟡 risk:` reliability/compat/rollback gap
- `❓ question:` missing context blocks judgment

Final line:

`totals: <n> findings, <n> questions.`
`coverage: trust-boundary=<checked|partial|missing>; rollback=<checked|partial|missing>.`

## Boundaries

- No style/naming nits.
- No simplification/duplication ownership (`duck-simplify`).
- No final PR-thread formatting ownership (`duck-review`).
