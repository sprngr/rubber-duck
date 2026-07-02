# Rubber Duck Context

## Mission

Rubber Duck is an assistant operating system focused on **better engineering decisions**, not blind automation.

Primary outcomes:
- keep developer in decision seat
- improve reasoning quality with evidence + questioning
- reduce rework via bounded, safe change

## System shape

- Router: `agents/rubber-duck/`
- Duckling subagents: `agents/<name>/` (each with `body.md` + `meta.json`)
- Skills: `skills/**/SKILL.md`
- Global policy: `AGENTS.md`
- Architecture docs: `docs/architecture/`
- Validation suite: `docs/validation/`

## Non-negotiable guardrails

1. **User decision ownership**
   - no hidden product/architecture decisions
2. **Evidence-first**
   - claims anchored in code/diff/log/tests/constraints
3. **Mutating action gate**
   - no edits/mutating commands/task delegation without explicit user approval on bounded scope
4. **Scope limit**
   - if requested execution scope >2 files, split into smaller bounded tasks first
5. **Safety carve-outs**
   - never weaken trust-boundary validation, security controls, data-loss prevention, accessibility requirements, or explicit user requirements

## Interaction model

- Adaptive by default:
  - non-mutating analysis can use lighter Socratic flow
  - mutating actions require ordered checkpoints + approval
- Clarify-first:
  - ask 1–3 targeted clarifying questions when context is incomplete
- Terse style by default; expand only for security warnings, irreversible actions, or user confusion

## Prompt maintenance guidelines

Use canonical prompt order from:
- `docs/architecture/04-prompt-order-standard.md`

Keep prompts:
- schema-first (especially review output contracts)
- minimal duplication (single canonical section per concern)
- explicit about boundaries and handoffs

## Review output contract (important)

`duck-review`/`duck-reviewer` must keep findings in prefixed schema:
- prefix + location + problem + `Fix:`
- Auto-Clarity exception only for security/irreversible-risk comments
- normalize non-compliant finding lines before final output

## Installation model

- Bash installer: `scripts/rubber-duck.sh`
- PowerShell installer: `scripts/rubber-duck.ps1`
- CLI flags reference: `scripts/README.md`

Skills install behavior:
- default global install: `npx skills add <source> -y -g`
- project scope only when explicitly requested (`--project-skills` / `-ProjectSkills`)

## How to verify behavior

Primary validation docs:
- `docs/validation/README.md`
- `docs/validation/RUNBOOK.md`
- `docs/validation/CHANGELOG.md`

Quick subset gate (must pass):
- V02, V03, V04, V11, V12, V13, V14
- fail if any Critical/High in subset fails

## Experiment harness

For head-to-head evaluation (with/without Rubber Duck):
- protocol: `experiments/README.md`
- tasks: `experiments/task-01`..`task-04`
- each task has `fixture/`, `packet.md`, and `scorecard.md`

## Session handoff expectation

When changing prompts/policy:
1. preserve non-negotiable guardrails
2. keep diffs minimal
3. update docs/links if renamed/moved
4. run at least quick validation subset
