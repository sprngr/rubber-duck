# Rubber Duck Architecture

This section defines the system-level architecture and operating contracts for Rubber Duck as an installable, reusable package.

## Documents

1. [01-philosophy.md](./01-philosophy.md) — product philosophy and decision ownership model.
2. [02-agent-skill-model.md](./02-agent-skill-model.md) — governor, quack routing, and skill architecture.
3. [03-adaptive-socratic-policy.md](./03-adaptive-socratic-policy.md) — adaptive default policy with strict checkpoints for mutating actions.
4. [04-prompt-order-standard.md](./04-prompt-order-standard.md) — canonical prompt section order and compression rules.
5. [05-harness-agent-config.md](./05-harness-agent-config.md) — per-agent, per-harness config model and the build-time renderer.
6. [06-skill-assembly-contract.md](./06-skill-assembly-contract.md) — source-to-artifact contract for skills (`src/skills` → `skills`) and drift controls.
7. [07-skill-asset-convention.md](./07-skill-asset-convention.md) — skill asset structure (`assets/` vs `references/`), metadata headers, and loading conventions.
8. [08-harness-best-practices.md](./08-harness-best-practices.md) — harness-specific UX tuning recommendations (Claude, Copilot, OpenCode).

## Validation

- [Validation prompt suite](../validation/README.md) — checklist prompts and expected signals for behavior regression checks.

## How this connects to current repository artifacts

- Governor definition: [`src/agents/rubber-duck/`](../../src/agents/rubber-duck)
- Explicit router skill: [`src/skills/quack/`](../../src/skills/quack)
- Delegation subagent (see [05-harness-agent-config.md](./05-harness-agent-config.md)):
  - [`src/agents/duckling/`](../../src/agents/duckling)
- Skills source: [`src/skills/`](../../src/skills)
- Skills install artifacts: [`skills/`](../../skills)
- Global operating policy: [`AGENTS.md`](../../AGENTS.md)

## Installation and distribution

Installation and distribution instructions live in the repository root [`README.md`](../../README.md) so users have a single entry point for setup guidance.
