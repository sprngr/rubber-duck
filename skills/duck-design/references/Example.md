# Example: Design Session Walkthrough

<!-- 
asset-type: reference
loading: conditional (informational, not typically loaded)
format: end-to-end conversation examples
last-updated: 2026-07-20
-->

End-to-end examples showing expected `duck-design` behavior.

## Core Scenario: Notifications for an Existing REST API

**User goal:** add real-time notifications.

### Conversation

#### User
```text
I need to add notifications to my app. Should I use WebSockets or polling?
```

#### Agent (Step 1: Clarify Intent)
```text
What constraint drives this choice most: performance, maintainability, or time to ship?
```

#### User
```text
Time to ship is critical. We launch in 2 weeks.
```

#### Agent (Step 4: Compare Alternatives)
```text
Your options: WebSockets vs polling.

Option A: WebSockets
- Strength: real-time, low latency.
- Weakness: higher infrastructure complexity (stateful connections, load balancer config, reconnect logic).
- Time to ship: ~5 days (new infra + client reconnect handling).

Option B: Polling
- Strength: simple implementation (reuse existing REST endpoints).
- Weakness: higher latency and more server requests.
- Time to ship: ~1 day (client timer + existing /notifications endpoint).

Which outcome matters most here, given your constraints?
```

**Literal closing sentence required for comparison blocks:**

```text
Which outcome matters most here, given your constraints?
```

#### User
```text
Polling for now. We can upgrade later if users complain about latency.
```

#### Agent (Step 7: Confirm Decision)
```text
Chosen: polling with the existing REST endpoint.

Accepted tradeoff: higher latency and request volume in exchange for faster delivery.

Document this as ADR?
```

#### User
```text
No, just implement it.
```

---

## Edge Case: Broad Plan Chunking

#### User
```text
Design a new microservices architecture. We need API gateway, service mesh, event bus, observability, and CI/CD pipeline.
```

#### Agent (Step 2: Chunk Broad Plans)
```text
What constraint drives this program most: delivery speed, risk reduction, or long-term maintainability?

That is 5 major components, each with dependencies and tradeoffs.

Main tradeoff: scope reduction now vs slower full-program change.

Slices:
1. API gateway (routing, auth)
2. Service mesh (inter-service comms)
3. Event bus (async messaging)
4. Observability (metrics, traces, logs)
5. CI/CD pipeline (build, deploy)

Start with API gateway, or different priority?
```

#### User
```text
API gateway first.
```

#### Agent (Step 1: Clarify Intent)
```text
What constraint drives gateway choice most: performance, security, or operational simplicity?
```

_Session continues with focused API gateway design discussion._

---

## Routing Disambiguation: Compare vs Chunk

### Case A: Compare Two Options (Step 4)

#### User
```text
Compare modular monolith vs two microservices for current checkout + inventory domains.
```

#### Agent
```text
What constraint drives this choice most: delivery speed, reliability, or team ownership?

Current approach strength: simplest operations for a small team.
Current approach weakness: tighter coupling across domains.

Alternative: split one domain first behind a clear interface.
New tradeoff: better isolation vs added deployment complexity.

Non-negotiable dimension: delivery speed now vs isolation later.

Which outcome matters most here, given your constraints?
```

### Case B: Multi-Component Rollout (Step 2)

#### User
```text
Plan full migration: auth rewrite, DB migration, event bus, new analytics pipeline, and service decomposition. Evaluate architecture.
```

#### Agent
```text
What constraint drives this program most: risk reduction, delivery speed, or long-term maintainability?

Main tradeoff: scope reduction now vs slower full-program change.

Slices:
1) auth migration boundary
2) database transition path
3) event contracts and replay safety
4) analytics ingestion parity
5) first domain extraction

Start with slice 1, or different priority?
```

**Note:** compact broad-plan style (around 10 lines) remains preferred.

---

## Edge Case: Validation Failure (Redirect)

#### User
```text
My cache keeps returning stale data. How should I design cache invalidation?
```

#### Agent (Boundary Check)
```text
This is runtime bug signal; redirect to duck-debug for runtime investigation.

Trace cache write/read paths first.

What should happen when a value is missing: no-op fallback or explicit validation error?

After cache logic is confirmed, return here to evaluate invalidation strategy (TTL vs event-based).
```

---

## Edge Case: Underspecified Prompt (Clarify Only)

#### User
```text
Design this.
```

#### Agent
```text
What constraint drives this choice?
```

### Rule

- Stop after a single scoping question.
- Do not add recommendations or alternatives before the user clarifies.
- Anti-pattern (do not do): question plus bullets, alternatives, or implementation plan before user clarification.

---

## Agent Calibration Notes

- **Tone:** Socratic. Ask before suggesting. Frame decisions as tradeoffs, not prescriptions.
- **Pacing:** Ask one clarifying question, then analyze. Avoid multi-question barrages.
- **Chunking trigger:** if scope is system-wide or has >3 components, slice and pick one first.
- **Output shape:** comparison responses always end with: "Which outcome matters most here, given your constraints?"
- **Boundary enforcement:** runtime bugs → `duck-debug`; test questions → `duck-triage`; keep `duck-design` focused on architecture/system choices.
