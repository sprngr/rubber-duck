# Rubber Duck 🦆 Operator Start Here

Practical operator guide for router behavior, handoff flow, and validation entrypoints.

For full architecture and policy details, use the canonical docs linked below.

## Canonical sources (single source of truth)

- Architecture index: [docs/architecture/README.md](./architecture/README.md)
- Philosophy and safety boundaries: [docs/architecture/01-philosophy.md](./architecture/01-philosophy.md)
- Agent/skill routing model: [docs/architecture/02-agent-skill-model.md](./architecture/02-agent-skill-model.md)
- Adaptive checkpoint policy: [docs/architecture/03-adaptive-socratic-policy.md](./architecture/03-adaptive-socratic-policy.md)
- Harness config/build model: [docs/architecture/05-harness-agent-config.md](./architecture/05-harness-agent-config.md)
- Validation prompts: [docs/validation/README.md](./validation/README.md)
- Validation runbook template: [docs/validation/RUNBOOK.md](./validation/RUNBOOK.md)
- Global operating policy: [AGENTS.md](../AGENTS.md)

## System map

### Router

- [rubber-duck](../agents/rubber-duck)

### Duckling subagents

- [duck-investigator](../agents/duck-investigator)
- [duck-reviewer](../agents/duck-reviewer)
- [duck-adversary](../agents/duck-adversary)
- [duck-simple](../agents/duck-simple)
- [duck-dry](../agents/duck-dry)
- [duck-builder](../agents/duck-builder)

### Skills

- [duck-debug](../skills/duck-debug/SKILL.md)
- [duck-review](../skills/duck-review/SKILL.md)
- [duck-design](../skills/duck-design/SKILL.md)
- [duck-explain](../skills/duck-explain/SKILL.md)
- [duck-teach](../skills/duck-teach/SKILL.md)
- [duck-triage](../skills/duck-triage/SKILL.md)
- [duck-debt](../skills/duck-debt/SKILL.md)

## Routing cheat sheet

| User signal | Start skill | Typical chain |
|---|---|---|
| “review this” + diff/code | `duck-review` | `duck-reviewer` + `duck-adversary` + `duck-simple` (+ `duck-dry` on duplication, + `duck-triage` on test-gap) |
| “debug this” + complaint | `duck-debug` | `duck-investigator` first, then `duck-triage` if repro weak, then `duck-builder` only on explicit bounded patch request |
| “design/tradeoffs” | `duck-design` | `duck-simple` + `duck-adversary` (+ `duck-dry` on shared-rule duplication) |
| “explain this” | `duck-explain` | escalate to debug/review if issue type shifts |
| “teach me/how works” | `duck-teach` | escalate to debug/review if issue emerges |
| “what to test/test coverage” | `duck-triage` | review handoff when inline PR comments are needed |
| “what did we defer/duck debt” | `duck-debt` | read-only debt ledger |

## Operator playbooks (copy/paste)

### Review

```text
Review this diff with duck-review. Prioritize security/correctness first.
If duplication appears, include duck-dry. If tests are missing, include duck-triage.
```

### Debug

```text
Debug this issue. Start with duck-investigator evidence map (defs/refs/callers/tests),
then run duck-debug root-cause questioning. Suggest patch target only after caller map.
```

### Design

```text
Evaluate this design with duck-design. Challenge constraints and tradeoffs.
Include duck-simple and duck-adversary lenses.
```

### Triage

```text
Triage this bug and test coverage. Classify severity, list missing tests,
and propose one minimum runnable check for non-trivial logic changes.
```

## Common failure modes

- Duplicate findings across ducklings.
  - Fix: merge by highest-risk priority into one final comment stream.
- Builder starts before evidence map.
  - Fix: run investigator/soft preflight first.
- Simplification suggestion hides a security/correctness issue.
  - Fix: surface risk-first finding first; simplification second if still needed.
- Scope exceeds builder boundary.
  - Fix: split into smaller bounded tasks before patching (`>2` files).

## Maintenance

- Treat architecture docs and skill files as canonical.
- Keep this file short and link-first.
- Use validation docs for behavior regression checks.

## Attribution

Conceptual attribution and mapping are maintained in the root [README.md](../README.md).
