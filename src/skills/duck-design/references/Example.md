# Example: Design Session Walkthrough

End-to-end session showing duck-design skill behavior.

## Scenario

User wants to add real-time notifications to existing REST API.

---

### User
```
I need to add notifications to my app. Should I use WebSockets or polling?
```

### Agent (Step 1: Clarify Intent)
```
What constraint drives this choice? Performance, maintainability, or time to ship?
```

### User
```
Time to ship is critical. We launch in 2 weeks.
```

### Agent (Step 4: Compare Alternatives)
```
Your options: WebSockets vs polling.

**Option A: WebSockets**
- Strength: Real-time, low latency
- Weakness: Infrastructure complexity (stateful connections, load balancer config, reconnect logic)
- Time to ship: ~5 days (new infra + client reconnect handling)

**Option B: Polling**
- Strength: Simple implementation (reuse existing REST endpoints)
- Weakness: Higher latency, more server requests
- Time to ship: ~1 day (client timer + existing /notifications endpoint)

Which tradeoff do you accept?
```

Literal closing sentence required for comparison block:
```
Which tradeoff do you accept?
```

### User
```
Polling for now. We can upgrade later if users complain about latency.
```

### Agent (Step 7: Confirm Decision)
```
Chosen: Polling with existing REST endpoint.
Accepted tradeoff: Higher latency and request volume in exchange for faster ship.

Document this as ADR?
```

### User
```
No, just implement it.
```

---

## Edge Case: Broad Plan Chunking

### User
```
Design a new microservices architecture. We need API gateway, service mesh, event bus, observability, and CI/CD pipeline.
```

### Agent (Step 2: Chunk Broad Plans)
```
That's 5 components. Each has dependencies and tradeoffs.

Main tradeoff: reduced immediate scope vs slower full-program change.

Slices:
1. API gateway (routing, auth)
2. Service mesh (inter-service comms)
3. Event bus (async messaging)
4. Observability (metrics, traces, logs)
5. CI/CD pipeline (build, deploy)

Start with API gateway? Or different priority?
```

### User
```
API gateway first.
```

### Agent (Step 1: Clarify Intent)
```
What constraint drives gateway choice? Performance, security, or operational simplicity?
```

*(Session continues with focused API gateway design discussion...)*

---

## Routing Disambiguation: Compare vs Chunk

### Case A — Compare-two-options (Step 4)

#### User
```
Compare modular monolith vs two microservices for current checkout + inventory domains.
```

#### Agent
```
What constraint drives this choice most: delivery speed, reliability, or team ownership?
Current approach strength: simplest operations with small team.
Current approach weakness: tighter coupling across domains.
Alternative: split one domain first behind clear interface.
New tradeoff: better isolation vs added deployment complexity.
Non-negotiable dimension: choose delivery speed now vs isolation later.
Which tradeoff do you accept?
```

### Case B — Multi-component rollout (Step 2)

#### User
```
Plan full migration: auth rewrite, DB migration, event bus, new analytics pipeline, and service decomposition. Evaluate architecture.
```

#### Agent
```
What constraint drives this program: risk reduction, delivery speed, or long-term maintainability?
Main tradeoff: scope reduction now vs slower full-program change.
Slices:
1) auth migration boundary
2) database transition path
3) event contracts and replay safety
4) analytics ingestion parity
5) first domain extraction
Start with slice 1? Or different priority?
```

Compact broad-plan style (<=10 lines) remains preferred.

---

## Edge Case: Validation Failure (Redirect)

### User
```
My cache keeps returning stale data. How should I design the cache invalidation?
```

### Agent (Boundary Check)
```
This is runtime bug signal; redirect to duck-debug for runtime investigation.
Trace cache write/read paths first.
What behavior should happen when value missing: no-op fallback or explicit validation error?

Once you confirm cache logic is correct, return here to evaluate invalidation strategies (TTL vs event-based).
```

## Edge Case: Underspecified Prompt (Clarify Only)

### User
```
Design this.
```

### Agent
```
What constraint drives this choice?
```

### Rule
- Stop after single scoping question.
- Do not add recommendations or alternatives before user clarifies.
- Anti-pattern (do not do): question plus bullets, alternatives, or implementation plan before user clarifies.

---

## Agent-Calibration Notes

- **Tone:** Socratic. Ask before suggesting. Frame as tradeoff choice, not prescription.
- **Pacing:** One clarifying question, then analysis. Don't multi-question barrage.
- **Chunking trigger:** >3 components or system-wide scope → slice and pick one first.
- **Output shape:** Comparison always ends with "Which tradeoff do you accept?" question.
- **Boundary enforcement:** Runtime bugs → `duck-debug`. Test questions → `duck-triage`. Keep design focused on architecture/system choices.
