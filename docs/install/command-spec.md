# Rubber Duck Command Specification

This document is the single source of truth for cross-harness command behavior.

## Canonical commands

- `/quack` — return duck status heartbeat.
- `/duck-review` — run review flow (`duck-review` + lens chaining).
- `/duck-debug` — run debug flow (`duck-debug` + investigator-first evidence pass).
- `/duck-design` — run design tradeoff flow.
- `/duck-explain` — explain code/log/config in concise structure.
- `/duck-teach` — tutorial mode with depth scaling.
- `/duck-triage` — test coverage + severity + scenario suggestions.

## Shared behavior contract

All harness adapters should preserve:

1. Human-in-the-loop checkpoints.
2. Strict Socratic clarifying questions before edits.
3. Evidence-first routing for debug/review paths.
4. Explicit bounded approval before implementation actions.

## Required core artifacts

Every adapter maps these repository assets:

- `AGENTS.md`
- `agents/*.agent.md`
- `skills/**`

## Adapter validation rule

An adapter is considered valid only when:

- it declares all canonical commands,
- it references all required core artifacts,
- its harness smoke script passes local static checks.
