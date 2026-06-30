# Rubber Duck Architecture

This section defines the system-level architecture and operating contracts for Rubber Duck as an installable, reusable package.

## Documents

1. [01-philosophy.md](./01-philosophy.md) — product philosophy and decision ownership model.
2. [02-agent-skill-model.md](./02-agent-skill-model.md) — router, agent, and skill architecture.
3. [03-adaptive-socratic-policy.md](./03-adaptive-socratic-policy.md) — adaptive default policy with strict checkpoints for mutating actions.
4. [04-prompt-order-standard.md](./04-prompt-order-standard.md) — canonical prompt section order and compression rules.

## Validation

- [Validation prompt suite](../validation/README.md) — checklist prompts and expected signals for behavior regression checks.

## How this connects to current repository artifacts

- Router definition: [`agents/rubber-duck.agent.md`](../../agents/rubber-duck.agent.md)
- Subagents:
  - [`agents/duck-investigator.agent.md`](../../agents/duck-investigator.agent.md)
  - [`agents/duck-reviewer.agent.md`](../../agents/duck-reviewer.agent.md)
  - [`agents/duck-adversary.agent.md`](../../agents/duck-adversary.agent.md)
  - [`agents/duck-simple.agent.md`](../../agents/duck-simple.agent.md)
  - [`agents/duck-dry.agent.md`](../../agents/duck-dry.agent.md)
  - [`agents/duck-builder.agent.md`](../../agents/duck-builder.agent.md)
- Skills directory: [`skills/`](../../skills)
- Global operating policy: [`AGENTS.md`](../../AGENTS.md)

## Installation and distribution

Installation and distribution instructions live in the repository root [`README.md`](../../README.md) so users have a single entry point for setup guidance.
