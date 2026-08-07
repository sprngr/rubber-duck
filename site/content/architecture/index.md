---
title: Architecture
---

# Architecture

Rubber Duck is a **policy + skills harness**: source files under `src/` compile into installable artifacts, an installer places them into your harness, and a managed policy block enforces safety at runtime.

Three architectural concerns:

- **[Source to Artifact](./source-to-artifact.md)** — how `src/` becomes `skills/`, `dist/`, and eventually your installed harness.
- **[Safety Gates](./safety-gates.md)** — the four checkpoints (framing → selection → execution approval → acceptance), phase caps, and refusal rules.
- **[Prompt Order Standard](./prompt-order.md)** — the fixed order of system prompts + policy + skills, and why it matters.

For deeper background, the [Reference](../reference/architecture/) subtree contains the authoritative architecture docs, synced from repo `docs/architecture/`.
