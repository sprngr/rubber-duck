# Grill with Ducks — Examples

Use these prompts to trigger this skill and keep routing crisp.

## Canonical invocations

1. "Grill this architecture plan with ducks before we implement anything."
2. "Pressure-test this design decision against our docs and assumptions."
3. "Walk every branch of this rollout plan and force tradeoff decisions."
4. "Challenge this proposal until we have explicit assumptions, risks, and rollback."

## Good fit signals

- The user wants interview-style questioning, one question at a time.
- The goal is decision quality, not immediate code changes.
- Tradeoffs, assumptions, or boundaries are still fuzzy.
- Existing docs/domain language should constrain the discussion.

## Not a fit (handoff)

- "Why is this endpoint returning 500?" → `duck-debug`
- "Which architecture option is better, A or B?" → `duck-design` (unless user explicitly asks for deep grilling)
- "Review this diff/PR." → `duck-review`
- "What tests are missing / what severity is this bug?" → `duck-triage`
- "Explain this function or log line." → `duck-explain`
- "Teach me how this works with examples." → `duck-teach`

## Hybrid session shape example

1. Checkpoint: "What exact problem are we solving?"
2. Checkpoint: "What options are on the table?"
3. Deep-dive trigger: "This is expensive to reverse — what is rollback?"
4. Deep-dive trigger: "Your claim conflicts with code/docs — which source is authoritative?"
5. Return to checkpoint: "Smallest safe next step to validate assumption X?"

## Close-out example

- Decision: Option B (event-driven integration)
- Evidence: Existing ADRs + current service boundaries in code
- Open risks: replay semantics and idempotency gaps
- Next approved step: 1-slice spike with explicit rollback criteria
