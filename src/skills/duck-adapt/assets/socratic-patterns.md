# Socratic Transformation Patterns

Practical patterns for converting imperative/autopilot steps into Socratic questioning flows.

---

## Pattern 1: Imperative -> Question

### Before (Imperative)

```
Step 3: Generate API endpoints from schema.
```

### After (Socratic)

```
Step 3: Analyze schema and present endpoint options.

Ask:
- Which resources should be exposed? (all schema entities or subset?)
- RESTful routes or custom endpoints?
- Nested resources or flat structure?

Present 2-3 options with tradeoffs:
- Option A: Full CRUD for all entities — comprehensive but large surface
- Option B: Read-only for most, write for core entities — safer but limited
- Option C: Custom endpoints matching use cases — targeted but requires use-case analysis

Ask: "Which approach fits your requirements?"
```

**Pattern:**

- Imperative "do X" -> Question "which X?" + options + tradeoffs

---

## Pattern 2: Autopilot -> Approval Gate

### Before (Autopilot)

```
1. Scan code for issues
2. Apply standard fixes
3. Commit changes
```

### After (Approval-Gated)

```
1. Evidence gathering: Scan code and identify issues
   - Output: Issue list with locations, types, severity

2. Present findings with rationale
   - Group by severity (critical, high, medium, low)
   - Show count per category
   - Cite locations and evidence

3. Ask: "Which issues should I fix? Reply with issue IDs."

4. For selected issues, apply Duck Ladder
   - Check if change truly needed
   - Check for existing patterns to reuse
   - Check for stdlib solutions
   - Propose minimal safe diff

5. Execution approval (BLOCKING GATE)
    - Preflight: target phase (stubs/interfaces, wiring/integration, implementation), target files (bounded for selected phase), expected behavior, verification check
    - Present list of changes broken down by file as formatted diff
    - Approval ask: "Reply with 'approve' to execute this scope."
    - Wait for approval (do not proceed without explicit "approve")

6. Apply fixes
   - Minimal safe diff per issue
   - Run verification check
   - Report results

7. Do NOT auto-commit
   - User reviews changes
   - User commits manually
```

**Pattern:**

- Autopilot steps -> Evidence gathering + presentation + user selection + approval gate + execution + user finalizes

---

## Pattern 3: Black-Box -> Evidence-First

### Before (Black-Box)

```
Step 2: Identify the root cause of the bug.
```

### After (Evidence-First)

```
Step 2: Gather evidence to narrow root cause.

Evidence sources:
- Definition: Where is the failing function defined? (file:line)
- Callers: What calls this function? (usage sites)
- Tests: What test coverage exists? (test files)
- Recent changes: What commits touched this? (git log)
- Error logs: What's the failure signature? (stack trace)

Evidence collection steps:
1. Read function definition and understand expected behavior
2. Map all call sites to understand usage contexts
3. Check test coverage to see what scenarios are verified
4. Review recent commits for related changes
5. Analyze error logs for patterns

Present evidence summary:
- Known: [what evidence confirms]
- Unknown: [what evidence gaps remain]
- Hypotheses: [theories based on evidence]
- Next investigation: [what to check next]

Ask: "Which hypothesis should we investigate first?"
```

**Pattern:**

- Black-box "figure out X" -> Evidence sources + collection steps + summary + hypothesis generation + user chooses direction

---

## Pattern 4: Single-Path -> Multi-Option

### Before (Single-Path)

```
Step 3: Use a singleton pattern to manage state.
```

### After (Multi-Option)

```
Step 3: Evaluate state management approaches.

**Current evidence:**
- Access pattern: [how state is accessed]
- Scope: [which modules need state]
- Concurrency: [single-threaded or multi-threaded]

**Options:**

**Option A: Singleton**
- Pros: Global access, single instance guarantee
- Cons: Hidden dependency, testing difficulty, tight coupling
- When: Truly global state with simple access pattern

**Option B: Dependency injection**
- Pros: Explicit dependencies, testable, flexible
- Cons: More boilerplate, must thread through call chain
- When: State scope is known, testing important

**Option C: Context object**
- Pros: Explicit but portable, easy to pass down
- Cons: Manual threading, can be verbose
- When: State needed in localized call tree

**Option D: Module-level state**
- Pros: Simple, explicit import
- Cons: Global but less controlled than singleton
- When: State naturally scoped to module

**Recommendation:** [Based on evidence, suggest one] — because [rationale]

**Ask:** "Which approach fits your architecture? Or is there another pattern you prefer?"
```

**Pattern:**

- Single recommendation -> Evidence analysis + multiple options + pros/cons + recommendation with rationale + user choice

---

## Pattern 5: Assumption -> Explicit Check

### Before (Assumption)

```
Step 2: Parse the JSON response.
```

### After (Explicit Check)

```
Step 2: Parse the response with validation.

**Assumptions to verify:**
- Response is valid JSON (not HTML error page)
- Response has expected schema (fields exist)
- Response is within size limits (not streaming payload)

**Validation steps:**
1. Check Content-Type header (application/json expected)
2. Parse JSON with error handling (catch SyntaxError)
3. Validate required fields exist (schema check)
4. Check for error structure ({"error": ...})

**If validation fails:**
- Log raw response for debugging
- Return structured error with context
- Do not proceed with invalid data

**Ask:** "Should we add schema validation library (e.g., Zod, Joi) or manual checks?"
```

**Pattern:**

- Hidden assumption -> Explicit assumption list + validation steps + failure handling + user choice on implementation

---

## Pattern 6: Complex -> Duck Ladder

### Before (Complex)

```
Step 4: Create a new abstraction layer for data access.
```

### After (Duck Ladder)

```
Step 4: Apply Duck Ladder before adding abstraction.

**Check each rung:**

**Rung 1: No change needed?**
- Is current data access actually causing problems?
- Evidence: [cite specific pain points or just speculation]

**Rung 2: Reuse existing pattern?**
- Does this project already have a data access pattern?
- Search: [check for existing data access helpers]
- Evidence: [findings from codebase search]

**Rung 3: Stdlib solution?**
- Can we use built-in database client directly?
- Language features that reduce need for abstraction?

**Rung 4: Already-installed dependency?**
- What's in package.json? (check ORM/query builder)
- Can we use existing library better?

**Rung 5: Smallest safe diff?**
- What's the minimal change that solves the problem?
- Can we add one helper function instead of full layer?

**Rung 6: Add abstraction (only if all above fail)?**
- What's the simplest abstraction that works?
- What problem does it solve that earlier rungs don't?

**Assessment:**
- Stopped at rung: [number]
- Rationale: [why this rung holds]
- Proposed change: [minimal change at this rung]

**Ask:** "Does this assessment match your understanding of the problem?"
```

**Pattern:**

- "Add new code" -> Duck Ladder check + evidence per rung + stop at first rung that holds + user confirms

---

## Pattern 7: Vague -> Bounded

### Before (Vague)

```
Step 1: Fix the authentication issues.
```

### After (Bounded)

```
Step 1: Clarify scope and expected behavior.

**Clarifying questions:**
1. Which authentication issues? (login failing, session expiry, token refresh, etc.)
2. What's the symptom? (error message, behavior, logs)
3. What scope? (specific auth flow, specific files, or system-wide review)
4. Expected behavior after fix? (what should work that doesn't now)

**After clarification:**
- Scope: [bounded phase scope]
- Symptom: [specific observable problem]
- Expected behavior: [one-sentence outcome]
- Verification: [smallest check to confirm fix]

**Execution approval:**
- Target phase: [Phase 1 stubs/interfaces | Phase 2 wiring/integration | Phase 3 implementation]
- Files: [bounded list for selected phase]
- Behavior change: [expected delta]
- Verification: [how to test]

**Present list of changes:**
- `[file A]`: [change description]
- `[file B]`: [change description]

**Approval ask:** "Reply with 'approve' to execute this scope."

**Wait for approval before proceeding.**
```

**Pattern:**

- Vague task -> Clarifying questions + bounded scope + expected behavior + verification + approval gate

---

## Pattern 8: Tell -> Show Options

### Before (Tell)

```
Step 3: Use bcrypt for password hashing.
```

### After (Show Options)

```
Step 3: Choose password hashing strategy.

**Context:**
- Already-installed: [check package.json]
- Platform: [Node.js, Python, etc.]
- Requirements: [speed, security level, compliance]

**Options:**

**Option A: bcrypt**
- Security: Industry standard, adaptive cost
- Performance: Slower (by design)
- Already installed: [yes/no]
- When: Security-first, acceptable latency

**Option B: scrypt**
- Security: Memory-hard, resistant to hardware attacks
- Performance: Configurable cost
- Already installed: [yes/no]
- When: High-security requirements

**Option C: argon2**
- Security: Winner of password hashing competition
- Performance: Best resistance to GPU/ASIC attacks
- Already installed: [yes/no]
- When: Highest security bar

**Duck Ladder check:**
- Is password hashing already implemented? (check existing code)
- Can we reuse existing hashing function? (project pattern)
- Which rung: [reuse existing if found, else add new with user choice]

**Recommendation:** [Based on context + Duck Ladder]

**Ask:** "Which hashing strategy fits your security/performance requirements?"
```

**Pattern:**

- "Use X" directive -> Context + multiple options + Duck Ladder check + recommendation with rationale + user choice

---

## Pattern 9: Fix -> Understand Then Fix

### Before (Fix)

```
Step 2: Change the API endpoint from POST to GET.
```

### After (Understand Then Fix)

```
Step 2: Investigate why endpoint needs to change.

**Evidence gathering:**
1. Current endpoint: [read current implementation]
2. Why POST originally? [check commit history, comments]
3. What breaks with POST? [symptom analysis]
4. Callers: [who calls this endpoint?]
5. Side effects: [does this endpoint mutate state?]

**Analysis:**
- POST vs GET semantics:
  - POST: intended for state-changing operations
  - GET: intended for read-only, cacheable operations

- Current endpoint behavior: [mutating or read-only?]
- Caller expectations: [what do callers assume?]
- REST/HTTP compliance: [which method matches semantics?]

**Options:**

**Option A: Change to GET**
- When: Endpoint is truly read-only, no side effects
- Risk: Breaks existing callers expecting POST
- Migration: Version API or update all callers atomically

**Option B: Keep POST**
- When: Endpoint has side effects or should not be cached
- Risk: May not match REST conventions if read-only
- Fix: Address symptom differently (why is POST a problem?)

**Option C: Add GET, keep POST (deprecation path)**
- When: Need backward compatibility
- Risk: Maintaining two endpoints
- Benefit: Gradual migration

**Ask:**
1. "Does this endpoint have side effects (mutate state)?"
2. "Why is POST problematic? (caching, semantics, tooling?)"
3. "Do we need to maintain backward compatibility?"

**After user answers:**
- Recommended option: [based on answers]
- Implementation scope: [files + changes]
- Verification: [how to test]

**Present list of changes:**
- `[file A]`: [change description]
- `[file B]`: [change description]

**Approval ask:** "Reply with 'approve' to execute this scope."
```

**Pattern:**

- Direct fix -> Evidence gathering + analysis + multiple options + questions + user input -> recommended fix + approval gate

---

## Pattern 10: Recommendation -> Exploration

### Before (Recommendation)

```
Use microservices architecture for better scalability.
```

### After (Exploration)

```
**Context:**
- Current architecture: [monolith, modular monolith, distributed, etc.]
- Scalability concern: [which part doesn't scale?]
- Team size: [affects complexity tolerance]
- Deployment model: [cloud, on-prem, hybrid]

**What problem are we solving?**
- Specific scalability bottleneck: [evidence from metrics]
- Or: Anticipated future scale: [growth projections]

**Options:**

**Option A: Microservices**
- Pros: Independent scaling, team autonomy, tech diversity
- Cons: Operational complexity, network latency, distributed debugging
- When: Clear service boundaries, multiple teams, proven scale need

**Option B: Modular monolith with scale-out**
- Pros: Simpler operations, shared-memory benefits, gradual extraction path
- Cons: Shared deployment, scale-all-together
- When: Unclear boundaries, small team, moderate scale

**Option C: Vertical scaling + optimization**
- Pros: Simplest, lowest complexity, fastest to implement
- Cons: Hardware limits, single point of scale
- When: Current scale is modest, problem is inefficiency not architecture

**Option D: Hybrid (extract hot paths)**
- Pros: Targeted complexity, optimize where needed
- Cons: Two operational models
- When: One component has different scale profile

**Duck Ladder check:**
- Rung 1: Is scaling needed now or speculative?
- Rung 5: What's smallest change that addresses bottleneck?

**Ask:**
1. "What's the specific scalability bottleneck? (evidence from metrics)"
2. "What scale are we targeting? (RPS, data volume, etc.)"
3. "What's the team size and ops maturity?"

**After answers:**
- Recommended option: [based on context]
- Rationale: [why this fits]
- Smallest next step: [what to do first]
```

**Pattern:**

- Direct recommendation -> Context gathering + problem clarification + multiple options + Duck Ladder + questions + user input -> tailored recommendation

---

## Summary: Transformation Principles

1. **Questions > Commands** — Ask before telling
2. **Options > Single Path** — Present alternatives with tradeoffs
3. **Evidence > Assumptions** — Ground in artifacts before conclusions
4. **User Choice > Assistant Choice** — User decides, assistant advises
5. **Explicit > Implicit** — Surface assumptions, constraints, tradeoffs
6. **Minimal > Maximal** — Duck Ladder before new code
7. **Bounded > Vague** — Clarify scope before execution
8. **Approval Gates > Autopilot** — Wait for "approve" before mutating actions
9. **Understanding > Fixing** — Investigate before changing
10. **Exploration > Prescription** — Help user discover solution vs imposing solution

Use these patterns when adapting external skills to rubber-duck philosophy.
