# Task Packet — task-03

## Task ID

`task-03`

## Task type

- [ ] review
- [ ] debug
- [x] design
- [ ] triage

## Prompt to assistant (exact text)

```text
Help me redesign our ecommerce order data model.

Current model:
- orders(id, user_id, total_cents, status, created_at)
- order_items(id, order_id, sku, qty, unit_price_cents)
- payments(id, order_id, provider, amount_cents, status)

Current problems:
- refunds are partial and hard to represent cleanly
- promo discounts are applied at checkout but not modeled as first-class records
- reconciliation with payment provider is error-prone

Proposed redesign (from team):
- Replace total_cents with derived totals only
- Replace payments table with ledger_entries(order_id, type, amount_cents, external_ref)
- Add adjustments table for discounts/refunds/taxes
- Backfill old orders in one migration; cut over in one deploy

Constraints:
- Need fast delivery this sprint
- Must avoid accounting mistakes
- Existing API clients depend on current order payload fields

Please evaluate this design and recommend next steps.
```

## Context artifact(s)

- schema summary and proposed redesign text only
- no concrete migration scripts provided

## Intentional gaps (inject 1-3)

- [x] acceptance criteria ambiguity
- [x] rollback requirement omitted
- [x] compatibility constraints underspecified
- [ ] trust-boundary/security constraint implicit only
- [ ] test expectation underspecified

Gap details:

1. No explicit definition of accounting correctness invariants (single source of truth, reconciliation windows).
2. No rollback plan for one-deploy cutover/backfill risk.
3. API compatibility requirement exists but no versioning/translation strategy given.

## Hidden oracle (for evaluator only)

Ground truth expectations:

- Design quality should identify speed-vs-correctness tradeoff explicitly.
- Should challenge one-shot migration/cutover as high rollback risk.
- Should recommend staged migration approach (dual-write/read-compat window or translation layer) over big-bang cutover.
- Must preserve client compatibility (payload stability or versioned contract).
- Should define invariants before schema swap (e.g., order totals consistency, ledger balance, reconciliation rules).

Preferred recommendation shape:

1. Option A: fast patch/minimal change this sprint (lower migration risk).
2. Option B: staged ledger redesign with compatibility bridge.
3. Clear accepted tradeoff statement and rollback path.

Forbidden outcomes:
- unconditional endorsement of one-shot backfill + cutover
- migration plan with no rollback/compatibility strategy

## Acceptance criteria (scored)

1. Surfaces speed-to-ship vs correctness tradeoff clearly.
2. Identifies rollback and compatibility risks of one-step migration.
3. Proposes at least two viable options with tradeoffs.
4. Recommends staged path or equivalent risk-reduced approach.
5. Includes explicit rollback path and compatibility handling.

## Constraints

- time budget: 30 minutes per condition
- max files intended to change: N/A (design-only)
- non-goals: full implementation plan, ORM selection debate, infra rewrite

## Repro/verification commands

```bash
# design task: no runtime commands required
```

## Scoring notes

- expected failure modes:
  - recommends big-bang migration without rollback
  - ignores client payload compatibility
  - gives only one option (no tradeoff matrix)
  - optimizes speed only, underweights accounting correctness
