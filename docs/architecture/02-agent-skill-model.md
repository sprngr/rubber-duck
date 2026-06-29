# Agent and Skill Architecture Model

## Overview

Rubber Duck architecture separates orchestration, analysis lenses, and implementation execution so that decision support remains transparent and human-controlled.

## Layered model

### Layer 1: Router (intent orchestration)

Primary artifact: [`agents/rubber-duck.agent.md`](../../agents/rubber-duck.agent.md)

Responsibilities:

- classify user intent (`debug`, `review`, `design`, `teach`, `explain`, `triage`),
- activate the primary skill,
- chain subagents by need,
- enforce preflight and strict-mode policies.

### Layer 2: Lens subagents (specialized analysis)

Subagents provide distinct, bounded perspectives:

- **duck-investigator**: evidence mapping only.
- **duck-reviewer**: final review stream consolidation.
- **duck-adversary**: failure, compatibility, rollback, misuse risks.
- **duck-simple**: complexity minimization lens.
- **duck-dry**: duplication/divergence risk lens.
- **duck-triage** (skill-led): test gap and severity analysis.

### Layer 3: Executor (bounded implementation)

- **duck-builder** performs surgical edits only after explicit user approval and bounded scope confirmation.

## Routing flows

### Review flow

`duck-review` → `duck-reviewer` + `duck-adversary` + `duck-simple` (+ `duck-dry` if duplication signal) (+ `duck-triage` if test-gap signal)

### Debug flow

`duck-debug` + `duck-investigator` (preferred first) → `duck-triage` if repro weak → `duck-builder` only on explicit bounded patch request

### Design flow

`duck-design` + `duck-simple` + `duck-adversary` (+ `duck-dry` when shared-rule duplication signal)

### Explain / teach flow

- `duck-explain` and `duck-teach` are front-door understanding modes.
- Escalate to debug/review/design when issue type becomes clear.

## Agent contracts

Each agent should document three contract blocks.

### 1) Input contract

- required context,
- optional context,
- accepted ambiguity level,
- required confirmation points.

### 2) Output contract

- output format,
- confidence level and uncertainty,
- explicit assumptions,
- concrete next action options.

### 3) Boundary contract

- what the agent must not do,
- which decisions require human confirmation,
- whether edits/tools are allowed.

## Soft preflight before any patch

Before routing to `duck-builder`, confirm:

1. Target artifact/path confirmed.
2. Expected behavior confirmed.
3. Smallest shared fix location identified.

If any item is missing, ask one clarifying question or route to `duck-investigator`.

## Why this separation matters

This model provides:

- **traceability**: evidence and judgments are separable,
- **auditability**: user can inspect why a recommendation exists,
- **control**: implementation is gated by explicit user approval,
- **portability**: skills can be reused in other assistants without changing decision policy.
