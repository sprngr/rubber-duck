# Grill with Ducks — Examples

Use these prompts to trigger this skill and keep routing crisp.

## Canonical invocations

1. "Grill this architecture plan before we implement."
2. "Pressure-test this design decision against our docs and assumptions."
3. "Challenge every branch of this rollout plan until we have explicit decisions."
4. "Grill me on this proposal until assumptions and rollback are explicit."

## Good fit signals

- User wants interview-style questioning, one question at a time
- Goal is decision quality, not immediate code changes
- Tradeoffs, assumptions, or boundaries are still fuzzy
- Existing docs/domain language should constrain discussion
- High-stakes decision (irreversible, expensive, trust-boundary)

## Not a fit (handoff)

- "Why is this endpoint returning 500?" → `duck-debug`
- "Which architecture option is better, A or B?" → `duck-design` (unless user explicitly asks for deep grilling)
- "Review this diff/PR." → `duck-review`
- "What tests are missing / what severity is this bug?" → `duck-triage`
- "Explain this function or log line." → `duck-teach`
- "Teach me how this works with examples." → `duck-teach`

## vs duck-design

| Dimension | duck-design | grill-with-ducks |
|-----------|-------------|------------------|
| **Mode** | Option comparison | Deep interrogation |
| **Output** | Tradeoff matrix, 2-4 options | One question at a time |
| **Depth** | Lighter Socratic touch | Relentless questioning |
| **Closure** | Recommendation with rationale | Explicit decision with evidence |
| **Use when** | Need to compare approaches | Need to validate assumptions and expose risks |

## Hybrid session shape example

1. Checkpoint: "What exact problem are we solving?"
   - User: "Need async event integration for orders."
2. Checkpoint: "What options are on the table?"
   - User: "Polling, webhooks, or message queue."
3. Deep-dive trigger: "This is expensive to reverse — what's rollback path for message queue option?"
   - User: "Can fall back to polling if queue fails."
4. Deep-dive trigger: "Your claim conflicts with current retry logic in order service — which should we trust?"
   - User: "Current retry logic is stale; new queue approach supersedes it."
5. Return to checkpoint: "Smallest safe next step to validate assumption that queue handles order volume?"
   - User: "1-week spike with 10% traffic."

## Close-out example

- **Decision**: Message queue integration (event-driven)
- **Evidence used**: Existing ADRs on async patterns, current service boundaries in `services/orders/`, queue capacity from infra team
- **Open risks**: Replay semantics unclear, idempotency gaps in consumer
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
