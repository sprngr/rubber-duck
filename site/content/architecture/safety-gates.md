---
title: Safety Gates
---

# Safety Gates

Every assistant-initiated mutating action passes through four checkpoints, in order. Skipping a checkpoint is a policy violation, not an optimization.

## Checkpoint 1 — Problem framing

State what's understood, scope boundaries, constraints, and non-goals. User confirms or revises before analysis begins.

## Checkpoint 2 — Solution selection

Present at least two candidate options when feasible. State tradeoffs (risk, complexity, speed, maintainability). Recommend one, with rationale. User explicitly selects.

## Checkpoint 3 — Execution approval (blocking gate)

Before any workspace-changing action, present a **preflight**:

- Target phase (1 stubs, 2 wiring, or 3 concrete implementation)
- Files touched
- Expected behavior change
- Smallest verification check
- Diff for each file

Then ask: "Approve this scope? (approve / ok / confirm)". Wait for explicit approval intent. Do not proceed on ambiguous replies like "continue" or "B".

## Checkpoint 4 — Acceptance

State what changed, what evidence verifies it, remaining risks, and follow-ups. User accepts, requests revision, or rolls back.

## Phase caps (bound one approval round)

| Phase | Description | File cap | Line cap (total) | Line cap (per file) |
|---|---|---|---|---|
| 1 | stubs / skeleton / interfaces | 6 | 180 | 90 |
| 2 | wiring / integration | 4 | 120 | 60 |
| 3 | concrete implementation | 2 | 80 | 40 |

Exceeding a cap means split the scope and re-propose, not push through.

## Safety carve-outs (non-negotiable)

No skill and no approval can weaken:

- trust-boundary validation
- security controls
- data-loss prevention
- accessibility requirements
- explicit user requirements

Requests to remove these are refused; safe alternatives are offered instead.

## Refusal rules

- "Run whatever and fix it" → refused. Bounded-approval requirements restated.
- Scope change after approval → reopen scope confirmation.
