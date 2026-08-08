---
title: Rubber Duck
---

# Rubber Duck

Socratic AI assistant for better engineering decisions.

Evidence-first. Bounded. Safe.

Rubber Duck is a policy + skills harness that helps teams reason clearly, challenge assumptions, and ship safer changes through explicit approval gates.

Start with [Install + Verify](./docs/) and run your first [Demo workflow](./demos/).

## Start here

1. [Install + Verify](./docs/) — get it running in minutes.
2. [Learn routing](./docs/invocation.md) — auto-routing vs `quack <intent>`.
3. [Run a real workflow](./demos/) — design, review, debug transcripts.

## Who this is for

- Teams that want sharper design/debug/review conversations before code changes.
- Developers who want explicit approval gates for mutating actions.
- Projects that value evidence-backed reasoning over fast speculation.

## Who this is not for

- "Just patch it fast" workflows with no checkpoint discipline.
- One-shot code generation where architecture and risk discussion is out of scope.
- Teams that do not want policy constraints on assistant behavior.

## Core sections

- **[Usage](./docs/)**  
  Installers, verification steps, invocation patterns, workflow map.

- **[Demos](./demos/)**  
  Static transcripts showing how rubber-duck sessions actually run.

- **[Skills Catalogue](./skills/)**  
  Grouped skill index with default/extra tiers and per-skill pages.

- **[Philosophy](./philosophy/)**  
  Duck Ladder, evidence-first reasoning, decision ownership.

- **[Architecture](./architecture/)**  
  Source-to-artifact flow, safety gates, prompt-order precedence.

## How the system works

`src/*` defines behavior -> build generates `skills/` and `dist/` -> installers place artifacts into your harness -> runtime policy + skills govern each turn.

See [Source to Artifact](./architecture/source-to-artifact.md) for the full flow.

Ready to try it? Go to [Usage](./docs/) and follow the 3-step quick start.

## Quick links

- [GitHub repository](https://github.com/sprngr/rubber-duck)
- [Project docs in repo](./reference/)
- [Report an issue](https://github.com/sprngr/rubber-duck/issues)
