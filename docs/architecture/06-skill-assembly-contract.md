# Skill Assembly Contract

## Purpose

Define the authoritative source-to-artifact model for skills and the checks that enforce it.

## Source of Truth

- Skill source lives in `src/skills/`.
- Canonical shared guardrails live in `src/skills/shared/GUARDRAILS.md`.

Do not hand-edit generated artifacts.

## Generated Artifacts

- Install artifacts are written to `skills/` (used by `npx skills`).
- Per-skill `references/GUARDRAILS.md` in `skills/duck-*/` is generated from canonical shared guardrails.

## Assembly Behavior

Assembler: `scripts/assemble-skills.sh`

- build mode (default):
  - copies `src/skills/duck-*/SKILL.md` to `skills/duck-*/SKILL.md`
  - copies `src/skills/duck-*/references/**` except `GUARDRAILS.md`
  - injects canonical guardrails into each `skills/duck-*/references/GUARDRAILS.md`
- check mode (`--check`):
  - verifies artifact parity (`skills/**` matches expected assembly output)
  - verifies portability deny-token rules
  - enforces `build/skill-assembly/rules.json` required files and text assertions

## Contract File

Rules file: `build/skill-assembly/rules.json`

Contract includes:
- scope and target paths
- required files
- text assertions
- portability deny tokens

## Drift Controls

- local checks:
  - `bash scripts/assemble-skills.sh --check`
  - `bash scripts/check-guardrails-drift.sh`
- CI checks:
- workflow `check-source-generated-artifacts.yml` (path-gated jobs)
  - generated artifact cleanliness check on pull requests

## Operator Commands

- rebuild skills: `bash scripts/assemble-skills.sh`
- verify skills: `bash scripts/assemble-skills.sh --check`
- umbrella: `make build` / `make check`

## Invariants

1. `src/skills/**` is authoritative.
2. `skills/**` is generated and must be reproducible.
3. Canonical guardrails come only from `src/skills/shared/GUARDRAILS.md`.
4. Any source change that affects skills must be reflected in generated artifacts.
