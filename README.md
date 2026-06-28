# Rubber Duck 🦆

Socratic assistant operating system for developers who want **better decisions**, not blind automation.

Rubber Duck helps you debug, review, design, and triage with structured questioning, evidence-first routing, and explicit safety guardrails.

## Why this approach

Most assistant setups optimize for speed-to-output. Rubber Duck optimizes for:

- decision quality,
- developer understanding,
- safe, bounded change,
- reduced rework from shallow fixes.

Core idea: keep human in control, keep reasoning explicit.

## Who this is for

Priority audiences:

1. **Solo developers** who want an assistant that sharpens thinking without taking over.
2. **Team leads** who need consistent review/debug behavior across contributors.
3. **Tinkerers** who want reusable agent/skill scaffolding with governance checks.

## Who this is not for

- If you want fully autonomous, no-checkpoint, end-to-end automated runs with minimal human involvement, this project is likely not a fit.

## Quick install

Interactive (recommended):

```bash
bash scripts/install-harness.sh
```

Direct harness install:

```bash
bash scripts/install.sh --opencode
bash scripts/install.sh --claude-code
bash scripts/install.sh --copilot
bash scripts/install.sh --pi
```

Skills-only install:

```bash
npx skills add https://github.com/sprngr/rubber-duck
```

## 5-minute first session

Use this to quickly validate behavior and fit in your own workflow.

### Step 1: heartbeat check

Prompt:

```text
quack
```

Expected:
- duck status response (router active).

### Step 2: review behavior check

Prompt:

```text
/duck-review
Review this snippet for correctness and simplification:

function parseAge(input) {
  return Number(input) || 0;
}
```

Expected:
- risk-aware findings first,
- concrete fix direction,
- no silent code edits.

### Step 3: debug behavior check

Prompt:

```text
/duck-debug
My endpoint returns 500 when userId is missing. Help me debug this.
```

Expected:
- clarifying questions first,
- evidence-first reasoning,
- explicit handoff/approval before implementation.

### OpenCode note

In OpenCode, same flow works with `quack` and duck commands/prompts after install.

If these three steps feel useful, continue with your real issue and keep the same question-first pattern.

## Harness support

| Harness | Tier | Meaning |
|---|---|---|
| OpenCode | Verified | Maintainer-tested locally |
| Claude Code | Scaffolded | Static checks + docs validated |
| GitHub Copilot | Scaffolded | Static checks + docs validated |
| Pi | Scaffolded | Static checks + docs validated |

For preference-based setup and verify/uninstall shortcuts:

- [docs/install/quickstart-by-preference.md](./docs/install/quickstart-by-preference.md)

## Verify after install

1. Start fresh session in your harness.
2. Run `quack`.
3. Run one workflow command (for example `/duck-review`) on a small sample.

## Deep dive docs

### Start here

- [Architecture index](./docs/architecture/README.md)
- [Philosophy](./docs/architecture/01-philosophy.md)
- [Agent + skill model](./docs/architecture/02-agent-skill-model.md)
- [Strict Socratic mode](./docs/architecture/03-strict-socratic-mode.md)

### Governance and policy adherence

- [Governance index](./docs/governance/README.md)
- [Rubric](./docs/governance/rubric.md)
- [Behavior tests](./docs/governance/behavior-tests.md)
- [Final governance summary](./docs/governance/final-summary-2026-06-28.md)

### Prompt contracts

- Router + subagents: [`agents/`](./agents)
- Skills: [`skills/`](./skills)

## Contributing (minimum checks)

```bash
make full-check
```

If you change `agents/*` or `skills/*`, include governance run evidence (local `docs/governance/runs/` plus PR summary per template).

## Attribution

Rubber Duck draws inspiration from related assistant-operating-system work such as Ponytail and Caveman, then adapts those ideas to a Socratic, human-in-the-loop model.

Token note: minimizing token usage through oversimplified output is not the goal. Minimizing token usage through clear understanding and precise communication is the goal.
