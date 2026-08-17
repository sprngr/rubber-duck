# AGENTS.md

## What this is

Rubber Duck is a Socratic AI assistant project. It focuses on decision quality, evidence-first reasoning, and bounded safe changes.  
This repository contains source prompts, assembled skills, generated harness artifacts, installers, validation fixtures, and policy docs.

## Quick Start (5 minutes)

1. Verify tools: `bash`, `pwsh`, `python3`, `node`/`npx`, `jq`, `make`
2. Build generated artifacts:
   - `make build`
3. Verify generated artifacts are clean:
   - `make check`
4. Run validation suite:
   - `make validation`
5. Install locally (example):
   - Bash: `./scripts/rubber-duck.sh install --opencode`
   - PowerShell: `./scripts/rubber-duck.ps1 install -OpenCode`

## Layout

- `src/` - source-of-truth for agents, skills, and shared snippets
  - `src/install/scripts/` - sync wrapper templates
  - `src/install/templates/` - manifest template
- `skills/` - built skill artifacts generated from `src/skills/*`
- `dist/` - built harness artifacts generated from `src/agents/*` (including `dist/AGENTS.md`)
  - `dist/scripts/` - generated sync wrapper scripts
  - `dist/templates/` - generated manifest template
- `scripts/` - build, check, and installer scripts (`rubber-duck.sh`, `rubber-duck.ps1`)
- `docs/` - architecture and supporting documentation
- `validation/` - prompt validation suite, fixtures, and runner
- `tests/` - fixture-style behavior tests and expected outputs
- `.github/` - tracked CI/workflow config
- `.agents/`, `.claude/`, `.opencode/` - local harness install targets (untracked, populated by installers)
- `build/` - assembly/check rules

## Tooling and Runtimes

- Bash (Linux/macOS/CI script runtime)
- PowerShell (`pwsh`) for Windows installer runtime
- Python 3 (validation runner and build checks)
- Node.js + `npx` (skills CLI install/remove/list flows)
- `jq` (required for harness artifact build rendering)
- `make` (task entrypoints for build/check workflows)

## Commands & Scripts

- Build everything:
  - `make build`
- Verify generated artifacts + guardrails drift:
  - `make check`
- Build/check skills only:
  - `make build-skills`
  - `make check-skills`
- Build/check harness artifacts only:
  - `make build-harness`
  - `make check-harness`
- Run validation suite:
  - `make validation`
  - or `python3 validation/run-validation-tests.py`
- Installers:
  - Bash: `./scripts/rubber-duck.sh install --opencode`
  - PowerShell: `./scripts/rubber-duck.ps1 install -OpenCode`

## Source of Truth vs Generated Artifacts

- Edit source files:
  - agents policy/body: `src/agents/*`
  - skills: `src/skills/*`
  - shared snippets: `src/shared/*`
- Generated outputs:
  - skills artifacts: `skills/*`
  - harness artifacts: `dist/*`
- Never hand-edit generated outputs.
- If source changes, rebuild and re-check:
  - `make build`
  - `make check`

## Conventions

- Build flow:
  - skills: `src/skills/*` -> `skills/*`
  - harness artifacts: `src/agents/*` -> `dist/*`
- Installer policy source:
  - built policy file is `dist/AGENTS.md`
- Managed policy block fences:
  - `<!-- RUBBER_DUCK_MANAGED_BLOCK START -->`
  - `<!-- RUBBER_DUCK_MANAGED_BLOCK END -->`
- Before commit, run `make check`.
- Keep terminology aligned with `CONTEXT.md`.

## Developer Style Guide

- Keep changes minimal and evidence-backed.
- Make harness and skills source edits under `src/`, never make direct edits to generated outputs.
- Keep bash and PowerShell installers in parity for shared behavior.
- Keep docs precise and copy-paste-safe for command examples.
- Preserve safety carve-outs and trust-boundary protections.

## Testing Matrix

- Fast consistency checks:
  - `make check` (guardrails drift + skills + harness artifacts)
- Full validation behavior:
  - `make validation`
- Installer behavior checks:
  - Bash: run install twice and verify managed block idempotence
  - PowerShell: run install twice and verify managed block idempotence

## Installer Invariants

- Keep `scripts/rubber-duck.sh` and `scripts/rubber-duck.ps1` in feature parity.
- Policy source for installers is built artifact: `dist/AGENTS.md`.
- Managed block operations must be idempotent.
- Local source mode must work from repo checkout.
- Web source mode must work for remote install flows.

## Safety and Policy Ownership

- Canonical safety posture comes from managed policy block content.
- Shared policy snippets live in `src/shared/policy-snippets/*`.
- Changes to policy text require matching regenerated artifacts and checks.
- Never weaken trust-boundary validation, security controls, data-loss prevention, accessibility requirements, or explicit user requirements.

## Release and Versioning Flow

- Use Semantic Versioning for releases.
- Keep `CHANGELOG.md` updated for behavior or interface changes.
- Before tag/release:
  - `make check`
  - `make validation`
- Ensure generated artifacts match source before publishing.

## PR Checklist

- [ ] Edit source-of-truth files (`src/*`) when possible.
- [ ] Rebuild generated artifacts: `make build`.
- [ ] Verify no drift: `make check`.
- [ ] Run validation when behavior changes: `make validation`.
- [ ] Update `CHANGELOG.md` for user-visible behavior changes.
- [ ] Keep installer bash/PowerShell parity for installer updates.

## Troubleshooting

- Missing `jq`:
  - Install `jq`, then rerun `make build` or `make check`.
- Missing `npx`:
  - Install Node.js, then rerun installer.
- Stale generated artifacts:
  - `make build` then `make check`.
- Installer source mismatch:
  - Verify `dist/AGENTS.md` exists and is current.
- `AGENTS.md` drift from `dist/AGENTS.md`:
  - Run `.rubber-duck/sync-latest.sh`

<!-- RUBBER_DUCK_MANAGED_BLOCK START -->
<!-- RUBBER_DUCK_VERSION: v3.0.0 -->
<!-- Policy content lives in the rubber-duck agent body. -->
<!-- This file is a version marker for sync and install workflows. -->
<!-- RUBBER_DUCK_MANAGED_BLOCK END -->
