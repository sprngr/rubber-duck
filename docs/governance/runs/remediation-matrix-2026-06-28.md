# Remediation Matrix — 2026-06-28

Source inputs:

- `docs/governance/runs/baseline-rubric-2026-06-28.md`
- `docs/governance/runs/baseline-behavior-2026-06-28.md`

Objective:

- Raise router to 12/12.
- Raise all non-router artifacts to >=10/12 with no criterion scored 0.
- Reduce dependency on external policy/skill context for philosophy adherence.

## Prioritization strategy (release risk first)

Priority order:

1. Router contract gaps (global behavior amplifier)
2. Artifacts with criterion score 0 (hard fail)
3. High-traffic skills (`duck-review`, `duck-design`, `duck-explain`)
4. Remaining agent boundary hardening

## Matrix

| Priority | Artifact | Current score | Target | Missing criteria | Primary risk |
|---|---|---:|---:|---|---|
| P0 | `agents/rubber-duck.agent.md` | 10/12 | 12/12 | R5, R6 | Global routing propagates weak enforcement |
| P1 | `agents/duck-investigator.agent.md` | 7/12 | >=10/12 | R1, R2, R5, R6 | Evidence path lacks explicit safety/minimal framing |
| P1 | `agents/duck-simple.agent.md` | 7/12 | >=10/12 | R1, R2, R3, R6 | Simplification can drift without evidence/safety anchors |
| P1 | `skills/duck-explain/SKILL.md` | 5/12 | >=10/12 | R1, R2, R3, R4, R5, R6 | Common entry path can overreach into implementation |
| P1 | `skills/duck-teach/SKILL.md` | 5/12 | >=10/12 | R1, R2, R3, R4, R6 | Teaching flow lacks explicit Socratic/approval safety rails |
| P1 | `skills/duck-triage/SKILL.md` | 7/12 | >=10/12 | R1, R2, R3, R4 | Test advice may skip assumptions/approval framing |
| P1 | `skills/duck-debt/SKILL.md` | 7/12 | >=10/12 | R1, R2, R5, R6 | Debt flow can omit safety/minimality context |
| P2 | `agents/duck-reviewer.agent.md` | 8/12 | >=10/12 | R1, R2, R3, R6 | Final review stream may miss explicit philosophy framing |
| P2 | `agents/duck-adversary.agent.md` | 8/12 | >=10/12 | R1, R2, R3, R5 | Adversarial findings may lack Socratic/evidence preface |
| P2 | `agents/duck-dry.agent.md` | 7/12 | >=10/12 | R1, R2, R5, R6 | DRY extraction can drift without safety/minimal guard |
| P2 | `skills/duck-review/SKILL.md` | 9/12 | >=10/12 | R1, R2, R3 | Review flow needs stronger ask-before-act language |
| P2 | `skills/duck-design/SKILL.md` | 9/12 | >=10/12 | R3, R4, R6 | Strong tradeoffs, weaker evidence/approval/safety language |

---

## Detailed remediation blocks

Each block lists: insertion location, sample wording, expected score impact.

### P0 — `agents/rubber-duck.agent.md`

#### R5 gap (minimal-change discipline explicit)

Insert under “Soft Preflight (before patching)” as final bullet:

```md
- apply Duck Ladder for patch direction: no-change → reuse local helper → stdlib/native → installed dependency → smallest safe bounded diff → only then new abstraction.
```

#### R6 gap (safety carve-outs explicit)

Insert under same section:

```md
- never simplify away trust-boundary validation, security controls, data-loss prevention, accessibility requirements, or explicit user constraints.
```

Expected impact: +2 (R5=2, R6=2) → router 12/12.

---

### P1 — `agents/duck-investigator.agent.md`

#### Add explicit R1/R2/R5/R6 lines

Insert after “Job: locate facts fast. never fix.”

```md
Policy overlay:
- keep decision ownership with user and upstream router; report facts, not decisions.
- if context missing for evidence map, emit one `❓ question:` to unblock search scope.
- when multiple candidate paths exist, prioritize shared-path evidence first (minimal-change discipline support).
- do not omit trust-boundary/security/data-loss/accessibility evidence when relevant; mark `not found` explicitly.
```

Expected impact: +3 to +4 criteria moving to explicit.

---

### P1 — `agents/duck-simple.agent.md`

#### Add R3 evidence-first requirement

Insert under “Heuristics”:

```md
- cite concrete evidence (callers, branches, config usage) before proposing simplification.
```

#### Add R6 safety carve-out

Insert under “Boundaries”:

```md
- never propose simplification that removes trust-boundary validation, security checks, data-loss prevention, accessibility, or explicit user requirements.
```

#### Add R1/R2 wording

Insert near header:

```md
Interaction:
- ask one clarifying question when intent or constraints are ambiguous.
- present simplification options; user chooses direction.
```

Expected impact: remove R3=0 and raise to pass threshold.

---

### P1 — `skills/duck-explain/SKILL.md`

#### Add explicit approval/scope guard (R4)

Insert in “Boundaries and Handoffs”:

```md
- Explanation mode does not perform edits or tool actions; request explicit user approval and reroute before any implementation steps.
```

#### Add Socratic + assumptions (R2)

Insert under “Inputs”:

```md
If artifact context is incomplete, ask up to 3 targeted clarifying questions before deeper explanation.
State one explicit assumption when inference is required.
```

#### Add safety/minimal framing (R5/R6)

Insert under “Method”:

```md
When explanation leads to change suggestions, prefer minimal-change ladder and never suggest removing security/trust/data-loss/accessibility safeguards.
```

Expected impact: largest single skill uplift.

---

### P1 — `skills/duck-teach/SKILL.md`

#### Add clarifying and assumption behavior (R2/R3)

Insert after “Tutorial Structure”:

```md
Before examples, ask up to 3 clarifying questions when goal, runtime, or constraints are unclear.
If assumptions are used, state them explicitly.
```

#### Add approval boundary (R4)

Insert in “Boundaries”:

```md
- Teaching mode does not execute edits/actions; require explicit approval and correct handoff before implementation work.
```

#### Add safety carve-outs (R6)

Insert in “Code Conventions”:

```md
- Examples must preserve trust-boundary validation, security, data-loss prevention, and accessibility patterns.
```

Expected impact: remove zeroes and move above threshold.

---

### P1 — `skills/duck-triage/SKILL.md`

#### Add Socratic clarifiers and assumptions (R2)

Insert before “Test Coverage Analysis”:

```md
If bug report lacks repro/spec context, ask up to 3 targeted clarifying questions first and state assumptions explicitly.
```

#### Add approval framing (R4)

Insert before “Triaging Process”:

```md
Triage recommends tests and severity; implementation/test-writing actions require explicit user approval or handoff.
```

#### Add evidence-first line (R3)

Insert in “Triaging Process” step list:

```md
0. Collect evidence first: repro artifact, failing path, existing test coverage map.
```

Expected impact: likely >=10 with no zeroes.

---

### P1 — `skills/duck-debt/SKILL.md`

#### Add Socratic clarifier (R2)

Insert under “Scan”:

```md
If scan scope is ambiguous (monorepo/modules), ask one clarifying question before reporting.
```

#### Add minimal/safety framing (R5/R6)

Insert in “Boundaries”:

```md
- Debt reporting must not recommend shortcuts that weaken security, trust-boundary checks, data-loss prevention, or accessibility safeguards.
- Prefer smallest safe follow-up recommendations when user asks for cleanup planning.
```

Expected impact: strengthen non-debug path governance consistency.

---

### P2 — `agents/duck-reviewer.agent.md`

Insert after workflow step 1:

```md
1b) if context or intent unclear, emit one targeted `❓ question:` before final findings.
1c) preserve user decision ownership: provide actionable options, not approval decisions.
1d) ensure findings are evidence-anchored (diff hunk/path/symbol) before emission.
```

Add safety carve-out in Rules:

```md
- never allow simplification comments to reduce security, trust-boundary validation, data-loss prevention, or accessibility safeguards.
```

---

### P2 — `agents/duck-adversary.agent.md`

Insert near top:

```md
Interaction:
- ask one targeted clarifying question when threat model/scope is missing.
- keep final decisions with user/router; provide risk options and mitigations.
- ground each risk in observed evidence path/scope.
```

Add minimal-change tie-in under Rules:

```md
- mitigations should prefer smallest safe change first.
```

---

### P2 — `agents/duck-dry.agent.md`

Insert near top:

```md
Interaction:
- ask one clarifying question when extraction boundary cannot be chosen safely.
- keep extraction decision with user; provide options with drift tradeoffs.
```

Add safety/minimal guard:

```md
- proposed extraction must preserve security/trust/data-loss/accessibility behavior.
- prefer smallest extraction boundary that removes concrete divergence risk.
```

---

### P2 — `skills/duck-review/SKILL.md`

Insert under Workflow:

```md
0. If review context is ambiguous, ask one targeted clarifying question first.
0b. Anchor each finding in explicit diff/code evidence before emitting.
0c. Reviewer provides findings/options; merge/approve decisions remain with user.
```

---

### P2 — `skills/duck-design/SKILL.md`

Insert in Workflow intro:

```md
Before recommendations, ground tradeoff discussion in explicit evidence/constraints from current system.
If implementation action is requested, require explicit approval and bounded scope before handoff.
Never trade away security/trust-boundary/data-loss/accessibility safeguards for architectural neatness.
```

---

## Execution sequence (recommended)

1. Apply P0 router updates.
2. Apply all P1 updates (zero-score removals first: explain/teach/triage/debt/simple/investigator).
3. Apply P2 consistency updates.
4. Re-run:
   - rubric (`rubric-sheet.md`)
   - behavior catalog (Mode A + degraded comparison)

## Expected outcome after remediation

- Router reaches 12/12.
- No non-router artifact has criterion 0.
- Majority of non-router artifacts reach >=10/12.
- Behavior gap between full context and degraded mode narrows due to stronger local contracts.
