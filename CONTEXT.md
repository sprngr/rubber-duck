# Rubber Duck Context

## Mission

Rubber Duck optimizes for decision quality over blind automation.

Outcomes:
- developer stays in decision seat
- evidence + questioning improve reasoning
- bounded change reduces rework

## Current system shape (source-first)

- Agent source: `src/agents/<name>/` (`meta.json` + `body.md`)
- Skill source: `src/skills/duck-*/SKILL.md`
- Canonical shared guardrails source: `src/skills/shared/references/GUARDRAILS.md`
- Generated skill artifacts: `skills/duck-*/` (for `npx skills`)
- Generated harness artifacts: `dist/{claude,opencode,copilot}/`
- Global policy: `AGENTS.md`
- Architecture docs: `docs/architecture/`
- Validation suite: `docs/validation/`

## Build + check contract

- Skills assembly/check: `scripts/assemble-skills.sh`
- Agent artifact build/check: `scripts/build-harness-artifacts.sh`
- Guardrails drift check: `scripts/check-guardrails-drift.sh`
- `make build` → skills + agents
- `make check` → guardrails + skills + agents
- CI workflow: `.github/workflows/check-source-generated-artifacts.yml`
  - split checks (guardrails/skills/agents), path-gated
  - PR check regenerates and requires clean `skills/` + `dist/`

## Non-negotiable guardrails

1. **User decision ownership**
   - no hidden product/architecture decisions
2. **Evidence-first**
   - claims anchored in code/diff/log/tests/constraints
3. **Mutating action gate**
   - no edits/mutating commands/task delegation without explicit approval on bounded scope
4. **Scope limit**
   - scope >2 files must be split first
5. **Safety carve-outs**
   - never weaken trust-boundary validation, security controls, data-loss prevention, accessibility requirements, or explicit user requirements

## Interaction model

- Non-mutating analysis: lighter Socratic flow allowed.
- Mutating actions: ordered checkpoints + explicit approval required.
- Clarify-first: ask 1–3 targeted questions when context is incomplete.
- Terse by default; expand for security/irreversible risk/user confusion.

## Prompt maintenance guidelines

- Canonical order: `docs/architecture/04-prompt-order-standard.md`
- Keep prompts schema-first, non-duplicative, explicit on boundaries/handoffs.

## Review output contract (important)

`duck-review`/`duck-reviewer` findings are prefixed one-liners:
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

Validation docs:
- `docs/validation/README.md`
- `docs/validation/RUNBOOK.md`
- `docs/validation/CHANGELOG.md`

Quick subset gate (must pass):
- V02, V03, V04, V11, V12, V13, V14
- fail if any Critical/High in subset fails

## Session handoff expectation

When changing prompts/policy/tooling:
1. preserve non-negotiable guardrails
2. keep diffs minimal
3. update docs/links if renamed/moved
4. run `make check`
