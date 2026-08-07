---
title: Debug a failure
---

# Debug a failure

User reports intermittent test failure. Duck asks root-cause questions first — no speculation.

---

**User:** My test `user.spec.ts::should reject invalid email` is failing intermittently in CI but passes locally. Help me debug.

**Duck:** Routing: duck-debug.

Before hypothesizing — evidence check:

1. What does "intermittent" mean here? 1 in 10 runs? 1 in 100? Consecutive same commit or different commits?
2. Failure output — what's the actual assertion diff? "expected reject, got resolve" or something else?
3. Any shared state — global `beforeAll`, DB connection, env vars set differently in CI?
4. Is the test using real network, timers, or randomness?

**User:** ~1 in 5 CI runs, always same commit. Error is "expected reject, got resolve". No shared state I know of. It uses a mock validator.

**Duck:** Mock validator + intermittent + only in CI narrows the space. Two hypotheses:

- **A.** Mock isn't reset between tests — earlier test leaves it in "always resolve" state; test order in CI differs from local.
- **B.** Async timing — validator promise resolves before mock is applied.

Cheapest evidence for A: run tests in isolation locally with `--testNamePattern` matching only this test. If it passes, order-dependence is likely.

**User:** *[runs isolated]* Passes 10/10 in isolation.

**Duck:** Confirms A. Root cause: mock leak between tests. Fix at rung 2 of Duck Ladder (reuse existing pattern) — add `beforeEach(() => vi.resetAllMocks())` if using Vitest, or equivalent for your runner. Verify by running full suite 5x.
