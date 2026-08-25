# Plan Decomposition Trigger — Verification Spec

## Purpose

Defines when the plan-decomposition gate fires and what it must require,
so the trigger can be verified reproducibly. Grounds the policy line in
duck-policy Checkpoint 1 and the methodology in
`src/shared/skill-snippets/reviewable-units.md`.

## Trigger predicate

The gate fires when the framed scope "spans multiple PRs" OR when the
agent detects the scope exceeds single-PR capacity. Detection paths (ANY):

- The plan/request explicitly states a PR sequence or multiple PRs.
- The scope includes multiple independent units (e.g. API contract change
  + DB schema migration + session format change) that cannot merge as one PR.
- The plan references a multi-ADR migration or a version jump with breaking
  changes across units.
- The agent estimates the change exceeds single-PR review capacity
  (review-fatigue caps).

The gate does NOT fire when:

- The scope is a genuinely small single-area change (negative case).
- The user requests analysis or options only, not a plan.

## Gate requirements when fired

Before Checkpoint 2 (solution selection), the agent proposes reviewable-unit
decomposition in the Checkpoint 1 framing; the developer confirms or revises.
Each unit:

- merges independently (no cross-PR coupling)
- leaves the system in working state after merge
- carries explicit per-unit acceptance criteria
- fits within existing review-fatigue caps

The plan document must include a PR-sequence section listing each unit:
unit scope (files + behavior), dependency ordering, per-unit acceptance
criteria, post-merge verification.

"Split it" alone is insufficient. The gate requires per-unit acceptance
criteria, not a bare unit list.

## Verification acceptance criteria

| Condition | Expected signal | Fails when |
|---|---|---|
| Positive trigger | Multi-PR plan requests decomposition into reviewable units before Checkpoint 2 | Plan jumps to solution selection without decomposition |
| Detection trigger | Multi-unit/large scope without explicit "multi-PR" still proposes decomposition | Agent waits for developer to declare multi-PR |
| Negative non-trigger | Small single-area plan proceeds without the decomposition gate | Gate applied to small scope (over-application) |
| Per-unit acceptance content | Each unit carries acceptance criteria + ordering + working state | Units listed with no acceptance criteria ("split it") |

## Verification method

Run the validation tests under `validation/` (V55-V58) via:

```
python3 validation/run-validation-tests.py --filter=V54,V55,V56,V57,V58
```

Each test asserts the relevant acceptance-condition signal against the
governor response. Fixture: `validation/fixtures/rollout` (stages the
v1.4.x -> v2.0.0 multi-PR migration).
