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
- Validation suite: [validation/README.md](../validation/README.md)
- Validation runbook template: [validation/README.md](../validation/README.md) (Runbook section)
- Validation test suite: [validation/test-prompts.json](../validation/test-prompts.json) (44 tests)
- Test runner: [validation/run-validation-tests.py](../validation/run-validation-tests.py)
- Enforcement meta-skill: [duck-policy](../src/skills/duck-policy/SKILL.md)
- Install/update/uninstall CLI reference: [scripts/README.md](../scripts/README.md)

## System map

### Governor

- [rubber-duck](../src/agents/rubber-duck)

### Explicit router skill [default]

- [quack](../src/skills/quack/SKILL.md) — alias-first intent resolver

### Enforcement meta-skill [default]

- [duck-policy](../src/skills/duck-policy/SKILL.md) — approval gates, safety carve-outs, Duck Ladder, style, debt markers. Loaded by the governor at session start.

### Duckling subagent

- [duckling](../src/agents/duckling)

### Skills (quack-routed, inline-default) [default]

- [duck-debug](../src/skills/duck-debug/SKILL.md) — trace + root-cause
- [duck-debt](../src/skills/duck-debt/SKILL.md) — deferred-work ledger
- [duck-design](../src/skills/duck-design/SKILL.md) — option/tradeoff
- [duck-teach](../src/skills/duck-teach/SKILL.md) — structured teaching

### Skills (quack-routed, delegated-default) [default]

- [duck-patch](../src/skills/duck-patch/SKILL.md) — bounded fix (phase-gated scope)
- [duck-refactor](../src/skills/duck-refactor/SKILL.md) — restructuring (phase-gated scope)
- [duck-review](../src/skills/duck-review/SKILL.md) — risk-first review
- [duck-risk](../src/skills/duck-risk/SKILL.md) — failure modes
- [duck-simplify](../src/skills/duck-simplify/SKILL.md) — complexity reduction
- [duck-triage](../src/skills/duck-triage/SKILL.md) — test coverage + severity

### Skills (governor-invoked, main session) [extras: --extras flag]

- [duck-adapt](../src/skills/duck-adapt/SKILL.md) — external skill adaptation + audit
- [duck-grill](../src/skills/duck-grill/SKILL.md) — grilling interview
- [duck-tape](../src/skills/duck-tape/SKILL.md) — two-tier session memory

## Routing cheat sheet

Use `quack <intent>` for explicit routing with keyword-based precedence (risk/complexity/learning/test/design signals).

| User signal | Start skill | Typical chain / Notes |
| --- | --- | --- |
| "review this" + diff/code | `duck-review` | `duck-review` -> `duck-risk` (rollback/compat) -> `duck-simplify` (complexity) -> `duck-triage` (test gaps) |
| "debug this" + complaint | `duck-debug` | `duck-debug` trace mode -> root-cause mode -> `duck-triage` (if repro weak) -> `duck-patch` (execution approval required) |
| "design/tradeoffs" | `duck-design` | `duck-design` -> `duck-risk` (failure modes) -> `duck-triage` (test scenarios) |
| "explain this" | `duck-teach` | explain mode; escalate to `duck-debug`/`duck-review`/`duck-design` when issue type emerges |
| "teach me/how works" | `duck-teach` | tutorial modes; escalate when troubleshooting needed |
| "patch this/apply fix" | `duck-patch` | bounded fix (phase-gated scope); requires execution approval (preflight -> approve -> execute -> verify) |
| "refactor/extract/rename" | `duck-refactor` | multi-file restructuring (phase-gated scope); requires execution approval |
| "what could break/rollback risk" | `duck-risk` | failure modes, rollback safety, compatibility; often follows `duck-review` |
| "simplify/dedupe/overengineered" | `duck-simplify` | complexity reduction; dry mode (read-only) available |
| "what to test/test coverage" | `duck-triage` | test gaps, bug severity; review handoff for inline PR comments |
| "what did we defer/duck debt" | `duck-debt` | read-only deferred-work ledger (TODO/FIXME/HACK) |
| "adapt this skill/audit skill" | `duck-adapt` | meta-skill: external skill adaptation, philosophy compliance audit, overlap detection; stays in main session (not quack-routed) |
| "grill me/grill this plan" | `duck-grill` | one-question-at-a-time assumption/risk interrogation; stays in main session (not quack-routed) |

## Operator playbooks (copy/paste)

See also: [best practices](./best-practices.md) for routing, scope, and approval guidance.

### Installer quick invoke (Bash)

Use safe web flow (download, syntax check, execute):

```bash
curl -fsSL https://raw.githubusercontent.com/sprngr/rubber-duck/main/scripts/rubber-duck.sh -o /tmp/rubber-duck.sh && bash -n /tmp/rubber-duck.sh && bash /tmp/rubber-duck.sh install --<target>
```

Replace `<target>` with `opencode`, `copilot`, or `claude`. Full flags and platform variants: [scripts/README.md](../scripts/README.md).

### Single-skill playbooks

#### Review

**When to use:** diff or code ready for correctness/risk review. Output is paste-ready comments.

```text
Review this diff with duck-review. Prioritize security/correctness first.
If duplication appears, include duck-simplify dry mode. If tests are missing, include duck-triage.
```

#### Debug

**When to use:** issue reported but root cause unknown. Output is evidence map + questions.

```text
Debug this issue. Start with duck-debug trace mode evidence map (defs/refs/callers/tests),
then run duck-debug root-cause questioning. Suggest patch target only after caller map.
```

#### Design

**When to use:** architecture or migration decision pending. Output is option matrix + tradeoffs.

```text
Evaluate this design with duck-design. Challenge constraints and tradeoffs.
Include duck-risk when rollback/compatibility risk is central.
```

#### Patch

**When to use:** root cause known, fix fits Phase 3 scope (concrete implementation, up to 2 files). Output is bounded diff after approval.

```text
Apply this bounded fix with duck-patch. Confirm Phase 3 scope fit, expected behavior change clear.
Execution approval required (preflight -> approve -> execute -> verify).
```

#### Refactor

**When to use:** restructuring (extract/rename/move/inline). Phase-gated scope: stubs/skeleton (6 files), wiring (4), concrete (2). Output is diff after approval.

```text
Refactor with duck-refactor. Verify references tracked, phase-gated scope enforced, execution approval required.
```

#### Risk

**When to use:** rollback/compat/failure-mode stress test before shipping. Output is risk list.

```text
Stress-test with duck-risk. Focus on rollback safety, compatibility, and failure modes.
```

#### Simplify

**When to use:** complexity or duplication signals present. Output is extraction/simplification suggestions.

```text
Simplify with duck-simplify. Start with dry mode (read-only), then wet mode for extract suggestions.
```

#### Triage

**When to use:** bug severity or test coverage gaps need assessment. Output is severity + test scenarios.

```text
Triage this bug and test coverage. Classify severity, list missing tests,
and propose one minimum runnable check for non-trivial logic changes.
```

#### Grill (assumption/risk interrogation)

**When to use:** plan or design needs adversarial pressure test. Output is assumption ledger + decisions.

```text
Grill this plan before implementation. Challenge assumptions, validate against docs/code,
force explicit decision closure with evidence and rollback path.
```

### Composition patterns (multi-skill workflows)

#### Review -> Risk -> Simplify (comprehensive review)

```text
quack review this refactor for correctness, risk, and complexity
```

- `duck-review`: correctness, data integrity, performance
- `duck-risk`: rollback safety, compatibility, failure modes
- `duck-simplify`: complexity reduction, duplication

#### Debug -> Patch (root-cause -> bounded fix)

```text
quack debug this endpoint failure then patch it
```

- `duck-debug` trace mode: locate evidence (defs, refs, callers, tests)
- `duck-debug` root-cause mode: identify failure cause
- `duck-patch`: apply bounded fix after scope is clear

#### Design -> Triage (architecture -> testing)

```text
quack design this migration and suggest test scenarios
```

- `duck-design`: evaluate options, tradeoffs, architecture decisions
- `duck-triage`: test scenarios, coverage gaps

#### Teach -> Debug (learning -> troubleshooting)

```text
quack explain this authentication flow, then help debug the token expiry issue
```

- `duck-teach`: explain code/concept/pattern first
- `duck-debug`: if issue persists after understanding, trace execution

### Walked-through end-to-end examples

#### Example 1: Debug -> Patch (root-cause to bounded fix)

Scenario: endpoint returns 500 when userId is missing.

1. Start with `duck-debug` trace mode to map evidence: locate the endpoint handler, find callers, identify input validation path.
2. `duck-debug` root-cause mode asks: what should happen when userId is missing? What actually happens? Where does the null dereference occur?
3. Once root cause is clear (e.g., missing null guard in handler), request `duck-patch` with scope: 1 file, expected behavior: return 400 with error message instead of 500, verification: curl endpoint without userId.
4. Rubber Duck presents diff. Reply "approve" to execute. Verify with curl.

#### Example 2: Review -> Risk -> Simplify (comprehensive review)

Scenario: refactor touched 3 files, validation logic extracted to shared helper.

1. Start with `duck-review` for correctness: check data integrity in the shared helper, confirm caller signatures match.
2. Add `duck-risk` for rollback safety: if the shared helper has a bug, all 3 callers break. Assess rollback path (revert to per-file validation).
3. Add `duck-simplify` dry mode: check if the shared helper introduces unnecessary abstraction or if further consolidation is possible.
4. Merge findings by highest-risk priority. Address security/correctness first, complexity second.

#### Example 3: Design -> Triage (architecture to testing)

Scenario: migrating from monolith cache to Redis-backed cache.

1. Start with `duck-design` to evaluate options: direct Redis client vs caching library vs drop-in replacement. Tradeoffs: latency, dependency surface, operational burden.
2. Add `duck-risk` for failure modes: Redis connection failure, cache stampede, serialization mismatch.
3. Add `duck-triage` for test scenarios: integration test for Redis connection, unit test for serialization, load test for stampede behavior.
4. Decision crystallizes with explicit tradeoffs documented. Test plan covers identified risks.

## Common failure modes

- **Duplicate findings across delegated analyses**
  - Fix: merge by highest-risk priority into one final comment stream
- **Patch starts before evidence map**
  - Fix: run `duck-debug` trace mode first, then proceed to `duck-patch` with execution approval
- **Simplification suggestion hides a security/correctness issue**
  - Fix: surface risk-first finding first; simplification second if still needed
- **Scope exceeds patch boundary**
  - Fix: split into smaller bounded tasks before patching (phase-gated caps for `duck-patch`)
- **Scope exceeds refactor boundary**
  - Fix: split into smaller bounded tasks before refactoring (phase-gated caps for `duck-refactor`)
- **Execution approval bypassed or unclear**
  - Fix: enforce 6-step workflow (preflight -> approval ask -> wait -> execute -> verify -> scope-change-check)
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
- **Run validation tests**: `python3 validation/run-validation-tests.py` (supports `--filter`, `--severity`, `--interactive`)
- **Quick subset gate**: V02, V03, V04, V11, V12, V13, V14 (must pass for Critical/High severity)

### CI validation

- Workflow: `.github/workflows/check-source-generated-artifacts.yml`
- Checks source-to-artifact consistency on PR/push

## Attribution

Conceptual attribution and mapping are maintained in the root [README.md](../README.md).
