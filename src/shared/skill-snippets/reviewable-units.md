## Reviewable Unit Decomposition

Decompose plans that span multiple PRs into reviewable units before writing the plan. A reviewable unit is a PR-sized change set that:

- merges independently (no cross-PR coupling)
- leaves the system in working state after merge
- carries explicit acceptance criteria
- fits within existing review-fatigue caps

Propose decomposition when the scope spans multiple PRs OR when the agent detects the scope exceeds single-PR capacity:

- scope touches multiple independent units/subsystems (e.g. API + DB + session)
- estimated change exceeds single-PR review capacity (review-fatigue caps)

The proposal is confirmed or revised by the developer at Checkpoint 1. Do not decompose genuinely small single-area changes.

When decomposition applies, the plan document must include a PR-sequence section listing each unit:

- unit scope (files + behavior)
- dependency ordering (which units must land first)
- per-unit acceptance criteria
- post-merge verification

Purpose: prevent review-churn (oversized plans) and rubber-stamping (unreviewable bulk).