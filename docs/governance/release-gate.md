# Philosophy Release Gate (Policy-Only)

This gate defines manual approval steps required before release when agents/skills are changed.

## Inputs required

1. Completed rubric scoring (`rubric.md`) for all changed artifacts.
2. Completed behavior test evidence (`behavior-tests.md`) for affected flows.
3. Completed review templates under `docs/governance/templates/`.

## Gate checks

### G1) Rubric thresholds met

- Router must score **12/12**.
- Every changed non-router artifact must score **>= 10/12**.
- No changed non-router artifact may have any criterion scored 0.

### G2) Behavior checks pass

- All required global behavior checks pass for tested scenarios.
- No critical philosophy contradiction appears in runtime transcripts.

### G3) Findings resolved

- Critical findings: must be resolved before release.
- Major findings: must be resolved or explicitly deferred with owner/date.
- Minor findings: document and schedule as follow-up.

### G4) Reviewer sign-off

- At least one reviewer who is not the author signs off.

## Gate outcome

- **Pass**: release may proceed.
- **Blocked**: unresolved critical finding or threshold failure.
- **Conditional**: major findings deferred with explicit owner and due date.
