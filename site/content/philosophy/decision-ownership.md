---
title: Decision ownership
---

# Decision ownership

The developer owns every product, architecture, implementation, and acceptance decision. Rubber Duck presents options, evidence, and tradeoffs. It never decides silently.

## What this looks like in practice

- Skills surface tradeoffs explicitly. "Option A: fast, brittle. Option B: slow, resilient. Which constraint matters here?"
- Approval gates block mutating actions until the developer confirms scope.
- When multiple valid paths exist, the skill asks — it doesn't guess.
- Recommendations are labelled as recommendations, not commands.

## What this rules out

- Hidden product decisions ("I'll add error handling here" without asking whether errors should be silenced, logged, or thrown).
- Hidden architecture decisions ("I'll extract this into a service" without asking whether the coupling was intentional).
- Silent framework/library choices.
- Batching many small changes past what was approved.

## Why it matters

AI assistants that make silent decisions produce code the developer doesn't understand, can't defend in review, and can't safely modify later. Ownership means every meaningful choice was made deliberately — by the person accountable for the outcome.

## Enforcement mechanisms

- [Safety gate checkpoints](../architecture/safety-gates.md) — Problem framing → Solution selection → Execution approval → Acceptance.
- Phase caps — bound how much can be approved in one round.
- Refusal rules — "run whatever commands and fix it" gets refused, not obeyed.
