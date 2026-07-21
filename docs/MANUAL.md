# Rubber Duck 🦆 Operator Start Here

Practical operator guide for governor behavior, handoff flow, and validation entrypoints.

For full architecture and policy details, use the canonical docs linked below.

## Canonical sources (single source of truth)

- Architecture index: [docs/architecture/README.md](./architecture/README.md)
- Philosophy and safety boundaries: [docs/architecture/01-philosophy.md](./architecture/01-philosophy.md)
- Agent/skill routing model: [docs/architecture/02-agent-skill-model.md](./architecture/02-agent-skill-model.md)
- Adaptive checkpoint policy: [docs/architecture/03-adaptive-socratic-policy.md](./architecture/03-adaptive-socratic-policy.md)
- Harness config/build model: [docs/architecture/05-harness-agent-config.md](./architecture/05-harness-agent-config.md)
- Skill assembly contract: [docs/architecture/06-skill-assembly-contract.md](./architecture/06-skill-assembly-contract.md)
- Skill asset convention: [docs/architecture/07-skill-asset-convention.md](./architecture/07-skill-asset-convention.md)
- Validation prompts: [docs/validation/README.md](./validation/README.md)
- Validation runbook template: [docs/validation/RUNBOOK.md](./validation/RUNBOOK.md)
- Validation test suite: [docs/validation/test-prompts.json](./validation/test-prompts.json) (21 tests)
- Test runner: [scripts/run-validation-tests.sh](../scripts/run-validation-tests.sh)
- Global operating policy: [AGENTS.md](../AGENTS.md)

## System map

### Governor

- [rubber-duck](../.agents/agents/rubber-duck)

### Explicit router skill

- [quack](../.agents/skills/quack/SKILL.md)

### Duckling subagent

- [duckling](../.agents/agents/duckling)

### Skills (duck-* suite, quack-routed)

- [duck-debug](../.agents/skills/duck-debug/SKILL.md)
- [duck-debt](../.agents/skills/duck-debt/SKILL.md)
- [duck-design](../.agents/skills/duck-design/SKILL.md)
- [duck-patch](../.agents/skills/duck-patch/SKILL.md)
- [duck-refactor](../.agents/skills/duck-refactor/SKILL.md)
- [duck-review](../.agents/skills/duck-review/SKILL.md)
- [duck-risk](../.agents/skills/duck-risk/SKILL.md)
- [duck-simplify](../.agents/skills/duck-simplify/SKILL.md)
- [duck-teach](../.agents/skills/duck-teach/SKILL.md)
- [duck-triage](../.agents/skills/duck-triage/SKILL.md)

### Skills (governor-invoked, main session)

- [duck-adapt](../.agents/skills/duck-adapt/SKILL.md)
- [duck-grill](../.agents/skills/duck-grill/SKILL.md)


## Routing cheat sheet

Use `quack <intent>` for explicit routing with keyword-based precedence (risk/complexity/learning/test/design signals).

| User signal | Start skill | Typical chain / Notes |
|---|---|---|
| "review this" + diff/code | `duck-review` | `duck-review` → `duck-risk` (rollback/compat) → `duck-simplify` (complexity) → `duck-triage` (test gaps) |
| "debug this" + complaint | `duck-debug` | `duck-debug` trace mode → root-cause mode → `duck-triage` (if repro weak) → `duck-patch` (execution approval required) |
| "design/tradeoffs" | `duck-design` | `duck-design` → `duck-risk` (failure modes) → `duck-triage` (test scenarios) |
| "explain this" | `duck-teach` | explain mode; escalate to `duck-debug`/`duck-review`/`duck-design` when issue type emerges |
| "teach me/how works" | `duck-teach` | tutorial modes; escalate when troubleshooting needed |
| "patch this/apply fix" | `duck-patch` | bounded fix (max 2 files); requires execution approval (preflight → approve → execute → verify) |
| "refactor/extract/rename" | `duck-refactor` | multi-file restructuring (max 5 files); requires execution approval |
| "what could break/rollback risk" | `duck-risk` | failure modes, rollback safety, compatibility; often follows `duck-review` |
| "simplify/dedupe/overengineered" | `duck-simplify` | complexity reduction; dry mode (read-only) available |
| "what to test/test coverage" | `duck-triage` | test gaps, bug severity; review handoff for inline PR comments |
| "what did we defer/duck debt" | `duck-debt` | read-only deferred-work ledger (TODO/FIXME/HACK) |
| "adapt this skill/audit skill" | `duck-adapt` | meta-skill: external skill adaptation, philosophy compliance audit, overlap detection; stays in main session (not quack-routed) |
| "grill me/grill this plan" | `duck-grill` | one-question-at-a-time assumption/risk interrogation; stays in main session (not quack-routed) |

## Operator playbooks (copy/paste)

### Single-skill playbooks

#### Review

```text
Review this diff with duck-review. Prioritize security/correctness first.
If duplication appears, include duck-simplify dry mode. If tests are missing, include duck-triage.
```

#### Debug

```text
Debug this issue. Start with duck-debug trace mode evidence map (defs/refs/callers/tests),
then run duck-debug root-cause questioning. Suggest patch target only after caller map.
```

#### Design

```text
Evaluate this design with duck-design. Challenge constraints and tradeoffs.
Include duck-risk when rollback/compatibility risk is central.
```

#### Patch

```text
Apply this bounded fix with duck-patch. Confirm scope ≤2 files, expected behavior change clear.
Execution approval required (preflight → approve → execute → verify).
```

#### Refactor

```text
Refactor with duck-refactor. Verify references tracked, max 5 files, execution approval required.
```

#### Risk

```text
Stress-test with duck-risk. Focus on rollback safety, compatibility, and failure modes.
```

#### Simplify

```text
Simplify with duck-simplify. Start with dry mode (read-only), then wet mode for extract suggestions.
```

#### Triage

```text
Triage this bug and test coverage. Classify severity, list missing tests,
and propose one minimum runnable check for non-trivial logic changes.
```

#### Grill (assumption/risk interrogation)

```text
Grill this plan before implementation. Challenge assumptions, validate against docs/code,
force explicit decision closure with evidence and rollback path.
```

### Composition patterns (multi-skill workflows)

#### Review → Risk → Simplify (comprehensive review)

```text
quack review this refactor for correctness, risk, and complexity
```

- `duck-review`: correctness, data integrity, performance
- `duck-risk`: rollback safety, compatibility, failure modes
- `duck-simplify`: complexity reduction, duplication

#### Debug → Patch (root-cause → bounded fix)

```text
quack debug this endpoint failure then patch it
```

- `duck-debug` trace mode: locate evidence (defs, refs, callers, tests)
- `duck-debug` root-cause mode: identify failure cause
- `duck-patch`: apply bounded fix after scope is clear

#### Design → Triage (architecture → testing)

```text
quack design this migration and suggest test scenarios
```

- `duck-design`: evaluate options, tradeoffs, architecture decisions
- `duck-triage`: test scenarios, coverage gaps

#### Teach → Debug (learning → troubleshooting)

```text
quack explain this authentication flow, then help debug the token expiry issue
```

- `duck-teach`: explain code/concept/pattern first
- `duck-debug`: if issue persists after understanding, trace execution

## Common failure modes

- **Duplicate findings across delegated analyses**
  - Fix: merge by highest-risk priority into one final comment stream
- **Patch starts before evidence map**
  - Fix: run `duck-debug` trace mode first, then proceed to `duck-patch` with execution approval
- **Simplification suggestion hides a security/correctness issue**
  - Fix: surface risk-first finding first; simplification second if still needed
- **Scope exceeds patch boundary**
  - Fix: split into smaller bounded tasks before patching (max 2 files for `duck-patch`)
- **Scope exceeds refactor boundary**
  - Fix: split into smaller bounded tasks before refactoring (max 5 files for `duck-refactor`)
- **Execution approval bypassed or unclear**
  - Fix: enforce 6-step workflow (preflight → approval ask → wait → execute → verify → scope-change-check)
- **Cosmetic vs semantic changes confused**
  - Fix: use two-tier approval (lightweight confirmation for whitespace/doc/formatting; full execution approval for code/config/logic changes)
- **Quack alias ambiguity**
  - Fix: use keyword-based precedence (risk/complexity/learning/test/design signals) or explicit skill name

## Maintenance

- Treat architecture docs and skill files as canonical
- Keep this file short and link-first
- Use validation docs for behavior regression checks

### Build/check commands

- **Build artifacts**: `make build` (or `scripts/assemble-skills.sh` + `scripts/build-harness-artifacts.sh`)
- **Check drift**: `make check` (or `scripts/check-guardrails-drift.sh`)
- **Run validation tests**: `scripts/run-validation-tests.sh` (supports `--filter`, `--severity`, `--interactive`)
- **Quick subset gate**: V02, V03, V04, V11, V12, V13, V14 (must pass for Critical/High severity)

### CI validation

- Workflow: `.github/workflows/check-source-generated-artifacts.yml`
- Checks source-to-artifact consistency on PR/push

## Attribution

Conceptual attribution and mapping are maintained in the root [README.md](../README.md).
