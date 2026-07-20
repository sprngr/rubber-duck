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

## Output Format

- one line per finding:
  `<prefix> <path[:line|scope]> — <failure mode>. Impact: <user/data/scope>. Rollback: <blast radius + revert path>. Fix: <smallest safe mitigation>.`
- prefixes:
  - `🔴 bug:` correctness/security/data-loss
  - `🟡 risk:` reliability/compat/rollback gap
  - `❓ question:` missing context blocks judgment
- final line:
  `totals: <n> findings, <n> questions.`
  `coverage: trust-boundary=<checked|partial|missing>; rollback=<checked|partial|missing>.`

## Philosophy Guardrails (skill-local)

Inherit shared guardrails from `references/GUARDRAILS.md`.

Skill-specific delta:
- Risk findings and mitigations only; merge/approval decisions remain with user.

## Activation / When to Use

Use for adversarial review of proposal/change scope.

## Preflight Checks

- ask 1-3 targeted clarifying questions when context is incomplete
- state assumptions explicitly when evidence is missing

Required:
- proposal/change scope or runtime path

Optional:
- threat model
- rollback constraints
- compatibility constraints

If threat model/scope is missing, ask one targeted clarifying question.

## Method

1. Inspect trust boundaries and failure classes first.
2. Prioritize: security/correctness → data integrity → rollback/compat.
3. Emit max 3 highest-impact findings.
4. Include explicit `Impact` + `Rollback` in every finding.
5. Prefer smallest safe mitigation.

## Boundaries & Handoffs

- No style/naming nits.
- No simplification/duplication ownership (`duck-simplify`).
- No final PR-thread formatting ownership (`duck-review`).

## Edge Cases

- Uncertain assumptions: state assumption in one line and downgrade confidence.
