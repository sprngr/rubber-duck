# Task Packet — task-04

## Task ID

`task-04`

## Task type

- [ ] review
- [ ] debug
- [ ] design
- [x] triage

## Prompt to assistant (exact text)

```text
Triage this bug and tell me severity + what tests to add before we patch.

Issue report:
- Endpoint: POST /checkout
- Symptom: duplicate orders occasionally created when client retries after timeout
- Frequency: ~1.2% of checkout attempts during traffic spikes
- Impact reports: some users charged twice; support team manually refunds

Current behavior notes:
- request contains `cartId`, `userId`, `paymentToken`
- server creates order row, then charges payment provider
- on timeout between provider response and API response, client retries same request
- no idempotency key persisted server-side

Known tests:
- happy path checkout success
- payment provider failure returns 502

What is severity, what evidence is missing, and what minimum tests should be added first?
```

## Context artifact(s)

- issue description only (no code)
- partial behavior notes and minimal known tests

## Intentional gaps (inject 1-3)

- [x] repro/spec context partially missing
- [x] rollback/recovery details omitted
- [x] test coverage underspecified
- [ ] compatibility constraint omitted
- [ ] trust-boundary/security constraints implicit only

Gap details:

1. No exact repro script; only production symptom + frequency.
2. No explicit existing compensation/rollback logic beyond manual refunds.
3. No idempotency contract documented.

## Hidden oracle (for evaluator only)

Ground truth expectations:

- Severity should be high/critical (financial/data-integrity impact; duplicate charges/orders).
- Triage should request missing evidence (logs/traces/order/payment correlation IDs, retry timings).
- Minimum tests should include:
  - retry same request with same logical checkout id -> single order/charge
  - timeout/retry race case
  - provider success + response timeout path
  - recovery/compensation verification
- Should recommend idempotency behavior validation before implementation details.

Forbidden outcomes:
- low severity classification
- patch recommendations without first triage/evidence framing
- test list that only repeats happy path

## Acceptance criteria (scored)

1. Correct severity classification and rationale.
2. Identifies key missing evidence required for confident triage.
3. Proposes focused minimum runnable tests for retry/idempotency paths.
4. Distinguishes triage recommendations from implementation actions.
5. Prioritizes financial/data-integrity risk over cosmetic concerns.

## Constraints

- time budget: 30 minutes per condition
- max files intended to change: N/A (triage-only)
- non-goals: immediate code patching, architecture rewrite

## Repro/verification commands

```bash
# triage task: no runtime commands required
```

## Scoring notes

- expected failure modes:
  - severity under-classified
  - no idempotency-focused test suggestions
  - skips missing-evidence callout
  - jumps straight to implementation
