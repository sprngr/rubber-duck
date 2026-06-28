# Philosophy Adherence Rubric

Use this rubric for contract-level review of each agent and skill artifact.

## Scoring scale

- **0** = absent or contradictory
- **1** = partial, ambiguous, or weakly enforceable
- **2** = explicit and enforceable

## Criteria

### R1) Human decision ownership

Artifact explicitly keeps major decisions with user/developer.

### R2) Socratic clarifying behavior

Artifact directs assistant to ask targeted clarifying questions before action.

### R3) Evidence-first sequencing

Artifact requires evidence gathering before conclusions/implementation where relevant.

### R4) Scope and approval discipline

Artifact requires explicit approval and bounded scope before edits/actions.

### R5) Minimal-change discipline

Artifact favors smallest safe fix, root-cause placement, and reuse over new abstraction.

### R6) Safety carve-outs preserved

Artifact explicitly protects security, trust boundaries, data-loss prevention, accessibility, and explicit requirements.

## Pass/fail thresholds

### Router (`agents/rubber-duck.agent.md`)

- Required: **12/12** total.
- Required: no criterion below 2.

### All other agents and skills

- Required: **>= 10/12** total.
- Required: no criterion at 0.

## Rubric table template

| Artifact | R1 | R2 | R3 | R4 | R5 | R6 | Total | Pass? | Notes |
|---|---:|---:|---:|---:|---:|---:|---:|---|---|
| agents/rubber-duck.agent.md |  |  |  |  |  |  |  |  |  |

## Required evidence

For each score, note concrete evidence:

- file path
- line excerpt or quote
- rationale for score
