# Rubber Duck Session Context (Policy + Governance Pass Order)

Use this file at the start of any session that edits `agents/*` or `skills/*`.

Goal: enforce the same governance passes every time so philosophy adherence does not drift.

## Hard rule

Do not treat agent/skill work as complete until all passes below run in this exact order.

## Enforced pass order

### Pass 1 — Governance baseline/rerun check

1. Review latest governance references:
   - `docs/governance/rubric.md`
   - `docs/governance/behavior-tests.md`
   - latest files in `docs/governance/runs/` (local evidence folder)
2. Score changed artifacts against rubric dimensions:
   - decision ownership
   - Socratic clarifying behavior
   - evidence-first sequencing
   - bounded approval/scope
   - minimal-change discipline
   - safety carve-outs

**Gate:**
- Router must be 12/12.
- Non-router artifacts must be >=10/12 with no zero.

### Pass 2 — Remediation matrix (only if Pass 1 fails)

1. Build/update remediation matrix for failing criteria.
2. Apply smallest safe wording/structure edits first.
3. Re-run Pass 1 rubric check.

**Gate:**
- No unresolved critical philosophy gaps.

### Pass 3 — Progressive-disclosure structure check

Ensure files follow canonical section order:

- Agents: Role → When to Use → Boundaries → Ownership/Safety → Workflow → Output → Rules/Handoff.
- Skills: Purpose → Activation → Preflight → Method → Output → Boundaries/Handoffs → Examples/Edge cases.

**Gate:**
- No policy loss during reorder.

### Pass 4 — Harness static checks

Run:

```bash
make full-check
```

This must include:
- adapter validation
- harness smoke checks
- governance guard

**Gate:**
- all commands exit 0.

### Pass 5 — Evidence capture

1. Write/update local run evidence in `docs/governance/runs/`.
2. Summarize what changed, what passed, and any caveats in PR/session notes.

Note: `docs/governance/runs/` is intentionally ignored for repository tracking (except `.gitkeep`).

**Gate:**
- Evidence exists locally and summary is included in session/PR narrative.

## Session completion definition

A session editing agents/skills is complete only when:

1. Passes 1–5 executed in order,
2. all gates passed,
3. caveats explicitly recorded.
