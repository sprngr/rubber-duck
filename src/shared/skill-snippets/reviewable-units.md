## Reviewable Unit Decomposition

Decompose multi-PR plans into reviewable units before writing the plan. A reviewable unit is a PR-sized change set that:

- merges independently (no cross-PR coupling)
- leaves the system in working state after merge
- carries explicit acceptance criteria
- fits within existing review-fatigue caps

When a plan spans multiple PRs, the plan document must include a PR-sequence section listing each unit:

- unit scope (files + behavior)
- dependency ordering (which units must land first)
- per-unit acceptance criteria
- post-merge verification

Purpose: prevent review-churn (oversized plans) and rubber-stamping (unreviewable bulk).