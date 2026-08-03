# Grill with Ducks — Examples

Use these prompts to trigger this skill and keep routing crisp.

## Canonical invocations

1. "Grill this architecture plan before we implement."
2. "Pressure-test this design decision against our docs and assumptions."
3. "Challenge every branch of this rollout plan until we have explicit decisions."
4. "Grill me on this proposal until assumptions and rollback are explicit."

## Good fit signals

- User wants deep interrogation with batched questions (up to 3 per turn)
- Goal is decision quality and assumption validation, not immediate code changes
- Tradeoffs, assumptions, or boundaries are still fuzzy
- Existing docs/domain language should constrain discussion
- High-stakes decision (irreversible, expensive, trust-boundary)
- Need pressure-tested plan with explicit assumption ledger

## Not a fit (handoff)

- "Why is this endpoint returning 500?" -> `duck-debug`
- "Which architecture option is better, A or B?" -> `duck-design` (unless user explicitly asks for deep grilling)
- "Review this diff/PR." -> `duck-review`
- "What tests are missing / what severity is this bug?" -> `duck-triage`
- "Explain this function or log line." -> `duck-teach`
- "Teach me how this works with examples." -> `duck-teach`

## vs duck-design

| Dimension | duck-design | duck-grill |
|-----------|-------------|------------------|
| **Mode** | Option comparison | Multi-turn deep interrogation |
| **Output** | Tradeoff matrix, 2-4 options | Batched questions (up to 3), assumption ledger |
| **Depth** | Lighter questioning (2-3 assumptions) | Pressure calibration, context threading, steel man |
| **Closure** | Stays in options space | Forces explicit decision closure |
| **Use when** | Quick comparison (~10-14 lines) | Deep assumption validation, risk exposure |

## Hybrid session shape example

**Turn 1 (Checkpoint batch):**
1. What exact problem are we solving?
2. What does 'done' look like for this decision?
3. What options are on the table?

(These can be answered in any order)

- User: "Need async event integration for orders. Done = decision locked with rollback path. Options: polling, webhooks, message queue."

**Turn 2 (Deep-dive, one at a time):**
- Question: "This is expensive to reverse — what's rollback path for message queue option?"
- User: "Can fall back to polling if queue fails."

**Turn 3 (Context threading):**
- Question: "You said 'fall back to polling' — but earlier you ruled polling out as too slow. That's a contradiction. Which constraint is negotiable: speed or rollback simplicity?"
- User: "Speed matters more. Rollback should be feature-flag cutover to standby polling process, accepting temporary slowdown."

**Turn 4 (Evidence gap signaling):**
- Question: "Code shows current retry logic in order service, but you claim new queue approach supersedes it. No ADR documents this decision — flagging as evidence gap. What was the decision rationale?"
- User: "Current retry logic is stale; queue handles retries natively."

**Turn 5 (Pressure calibration - user hedging):**
- User: "Queue *probably* handles our order volume..."
- Question: "Probably? This is a payment-critical path — data loss risk. Show me capacity specs or flag this as unvalidated assumption."
- User: "Fair — flagging as unvalidated. Need load test before commit."

**Turn 6 (Pivot detection):**
- Question: "Your answers suggest the real problem is 'we lack observability to validate queue capacity', not 'choose integration pattern'. Should we redirect to establishing metrics first?"
- User: "No — stick with integration choice, but add observability as prerequisite in rollout plan."

## Close-out example

- **Decision**: Message queue integration (event-driven)
- **Evidence used**: Existing ADRs on async patterns (ADR-007: Event Architecture), current service boundaries in `services/orders/`, queue capacity from infra team
- **Assumptions ledger**:
  1. "Queue handles 10K req/min" — deferred (validation plan: 1-week load test with 10% traffic)
  2. "Rollback via feature flag" — validated (existing flag system in `feature-flags/`)
  3. "Queue native retry sufficient" — invalidated (needs idempotency layer; see payment service pattern)
- **Open risks**: Replay semantics unclear, idempotency gaps in consumer (see assumption #3)
- **Out of scope**: Real-time analytics dashboard (important but beyond integration decision; separate effort)
- **Next approved step**: 1-week spike with 10% traffic, explicit rollback to polling if P95 latency exceeds 500ms

## Domain language pressure-test example

**Turn 1:**
- Question: "You said 'user' — do you mean account holder, end customer, or admin user?"
- Why this matters: Order service uses all three, and retry logic differs per role.

**Turn 2:**
- Question: "CONTEXT.md defines 'user' as account holder. Does that match your intent here?"
- Why this matters: If not, we need to update glossary before designing integration.

**User response**: "Yes, account holder."

**Turn 3:**
- Question: "Does webhook option preserve account holder identity through retry?"
- Why this matters: Current webhook impl strips user context on retry (see `webhooks/retry.ts:44`).

## Batching example (checkpoint questions)

**Turn 1 (batched checkpoint questions):**
1. What constraint drives this choice — performance, maintainability, or time-to-ship?
2. Who needs to approve this before rollout?
3. What's the current pain you're solving?

(These can be answered in any order)

**Turn 2 (deep-dive questions stay sequential):**
- Question 1: "You chose microservices for 'maintainability' — but your team is 3 people. How does operational complexity of 5 services improve maintainability over a modular monolith?"
- (Wait for answer before asking next deep-dive question)

## Steel man challenge example

**Context:** User chose SQL database over document store.

**User defense:** "We need relational structure and ACID guarantees."

**Steel man challenge:**
"Steel man for document store: Your service handles high write volume with flexible schema evolution (orders add custom fields per merchant). Document store's horizontal scaling handles growth without migration pain, and transaction support in MongoDB 4+ covers your ACID needs. Indexing on nested fields would simplify your current JOIN-heavy queries. Given those strengths, why is SQL still the better choice?"

**User response:** "Fair point on schema flexibility — but our compliance audit requires PostgreSQL-specific row-level security. That's non-negotiable."

**Result:** Steel man exposed the real constraint (compliance), not just "relational structure."

## Pressure calibration example

**Low stakes + clear evidence (lighter touch):**
- Question: "Code shows retry logic in `AuthService.authenticate()` already handles this. Rollback path?"
- (Quick, moves on fast)

**High stakes + hedging (increase pressure):**
- User: "The API *probably* handles retries..."
- Question: "Probably? This is a payment endpoint — data loss risk. Show me the retry code or flag this as unvalidated assumption requiring load test."
- (Demands concrete evidence or explicit uncertainty acknowledgment)

## Context threading example

**Turn 1:**
- Question: "What's your rollback plan?"
- User: "Manual config revert"

**Turn 3 (referencing Turn 1):**
- Question: "You said 'manual config revert' earlier — but your timeline mentions schema migration. How does manual revert handle schema changes? That's a contradiction."
- (Surfaces tension between previous answers)
