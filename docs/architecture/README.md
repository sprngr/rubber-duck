# Rubber Duck Architecture

This section defines the system-level architecture and operating contracts for Rubber Duck as an installable, reusable package.

## Documents

1. [01-philosophy.md](./01-philosophy.md) — product philosophy and decision ownership model.
2. [02-agent-skill-model.md](./02-agent-skill-model.md) — governor, quack routing, and skill architecture.
3. [03-adaptive-socratic-policy.md](./03-adaptive-socratic-policy.md) — adaptive default policy with strict checkpoints for mutating actions.
4. [04-prompt-order-standard.md](./04-prompt-order-standard.md) — canonical prompt section order and compression rules.
5. [05-harness-agent-config.md](./05-harness-agent-config.md) — per-agent, per-harness config model and the build-time renderer.
6. [06-skill-assembly-contract.md](./06-skill-assembly-contract.md) — source-to-artifact contract for skills (`src/skills` -> `skills`) and drift controls.
7. [07-skill-asset-convention.md](./07-skill-asset-convention.md) — skill asset structure (`assets/` vs `references/`), metadata headers, and loading conventions.

## Validation

- [Validation prompt suite](../validation/README.md) — checklist prompts and expected signals for behavior regression checks.

## How this connects to current repository artifacts

- Governor definition: [`src/agents/rubber-duck/`](../../src/agents/rubber-duck)
- Explicit router skill: [`src/skills/quack/`](../../src/skills/quack)
- Delegation subagent (see [05-harness-agent-config.md](./05-harness-agent-config.md)):
  - [`src/agents/duckling/`](../../src/agents/duckling)
- Skills source: [`src/skills/`](../../src/skills)
- Skills install artifacts: [`skills/`](../../skills)
- Global operating policy: [`src/agents/AGENTS.md`](../../src/agents/AGENTS.md)

## Governance Boundaries

### AGENTS.md vs CONTEXT.md

`AGENTS.md` is rules and operating contract.  
`CONTEXT.md` is project memory and decisions.

- **AGENTS.md**
  - defines agent behavior constraints
  - safety gates, approval flow, style constraints, hard boundaries
  - normative operating policy
- **CONTEXT.md**
  - records project decisions and conventions
  - glossary, open questions, deferred debt, working memory
  - descriptive project memory

Quick test:
- “Must ask for `approve` before semantic edit” -> `AGENTS.md`
- “Policy source moved to `dist/AGENTS.md` on 2026-08-04” -> `CONTEXT.md` (and maybe `CHANGELOG.md`)

Rule of thumb:
- If violation can create unsafe or unauthorized behavior, put it in `AGENTS.md`.
- If it prevents re-derivation across sessions, put it in `CONTEXT.md`.

### CONTEXT.md vs CHANGELOG.md

- **CONTEXT.md** tracks current project memory and active decisions for future sessions.
- **CHANGELOG.md** tracks release-visible changes over time for consumers and maintainers.

### CONTEXT.md vs ADRs

- **CONTEXT.md** stores evolving memory and active decision context.
- **ADRs / architecture docs** store durable architecture decisions with rationale and long-term reference value.

### Source-of-truth vs generated artifacts

- Edit source in `src/`.
- Treat `skills/` and `dist/` as generated outputs.
- Rebuild and verify after source changes (`make build`, `make check`).

## Installation and distribution

Installation and distribution instructions live in the repository root [`README.md`](../../README.md) so users have a single entry point for setup guidance.
