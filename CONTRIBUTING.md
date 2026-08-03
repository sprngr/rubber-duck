# Contributing to Rubber Duck 🦆

We welcome contributions. Read this guide before opening an issue or pull request.

## Core Philosophy

Rubber Duck is a Socratic assistant, not an autonomous code generator. All contributions must align with the core philosophy:
- **Decision ownership:** Keep the developer in control.
- **Ask-before-act:** Agents must clarify scope before proposing changes.
- **Bounded execution:** No silent edits. Every mutating action requires explicit approval.

Read the full [Philosophy](./docs/architecture/01-philosophy.md) before designing a new feature or skill.

## How to Contribute

### 1. Reporting Bugs
- Use the [issue tracker](https://github.com/sprngr/rubber-duck/issues).
- Provide a minimal reproduction path.
- Include the active agent target (Claude Code, Copilot, OpenCode) and the specific skill invoked (e.g., `duck-debug`).

### 2. Suggesting Features
- Open an issue to discuss the feature before writing code.
- Frame the suggestion around *decision quality* and *developer understanding*. Features aimed purely at raw token output or autonomous background looping will be rejected.

### 3. Adding New Skills
If you are contributing a new skill to the `src/skills/` directory:
- Follow the existing prompt contract structure in `src/skills/`.
- Ensure the skill delegates mutating actions back to the approval gate.
- Maintain terse language. Use fragments, short sentences, and zero hedging.
- Run `make build-skills` to regenerate `skills/` from `src/`.
- Run `make check` to verify guardrails drift and artifact consistency.

### 4. Architectural Standards
- **Scope:** Keep pull requests small and bounded, much like the tool itself.
- **Composition:** Reuse snippets where available for consistency across skills.
- **Skills-first:** Skills are a robust, well-defined standard across harnesses. New features should be skill-first. See [agentskills.io](https://agentskills.io) for more info.
- **Conventions:** See [CONTEXT.md](./CONTEXT.md) for naming, build workflow, and routing model conventions.

## Pull Request Process

We keep PR requirements lightweight. No strict commit message formats or required hooks. Clear communication and good judgment.

1. Fork the repo and create your branch from `main`.
2. Keep the scope of your PR tight. One feature or fix per PR.
3. Provide a clear description in your PR of *why* the change is being made and how it was tested.
4. If you add or modify a skill, ensure any new prompt contracts are documented in `docs/MANUAL.md` and the validation suite in `validation/` is updated.
5. Run `make build` and `make check` before submitting. Run `make validation` if behavior is affected.
6. Submit the PR. A maintainer will review it for scope, code quality, and philosophical alignment.