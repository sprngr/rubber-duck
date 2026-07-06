# Skill Assembly Contract

## Purpose

Define the authoritative source-to-artifact model for skills and the checks that enforce it.

## Source of Truth

- Skill source lives in `src/skills/`.
- Canonical shared guardrails live in `src/shared/references/GUARDRAILS.md`.

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
  - enforces `build/skill-assembly.rules.json` required files, directory file-set checks, and assertion groups

## Contract File

Rules file: `build/skill-assembly.rules.json`

Contract includes:
- scope and target paths
- required files
- grouped assertions (`skill_groups` + `group_assertions`)
- portability deny tokens

Contract style note:
- prefer minimal anchor `required_files` plus `required_dir_file_sets` for low-churn enforcement; avoid per-item inventory lists.

## Rules Schema (Current)

Shared checker: `scripts/lib/check-rules.py`

Used by:
- `scripts/assemble-skills.sh` with:
  - `--groups-key skill_groups`
  - `--group-file-template 'src/skills/{item}/SKILL.md'`
- `scripts/build-harness-artifacts.sh` with:
  - `--groups-key agent_groups`
  - `--group-file-template 'src/agents/{item}/body.md'`

Supported `checks` keys:
- `required_files` — explicit source files that must exist
- `required_dir_file_sets` — per-directory file-set requirements (each matched dir must contain listed files)
- `text_assertions` — optional direct file assertions (`file` + `contains`)
- `<groups-key>` (`skill_groups` or `agent_groups`) — named groups of items
- `group_assertions` — named assertion arrays mapped to group names

Directory file-set behavior:
- each entry defines `dirs_glob` + `required_files`
- checker resolves directories matched by `dirs_glob`
- each matched directory must contain every filename in `required_files`
- if no directories match a `dirs_glob`, check mode fails

Grouped assertion behavior:
- each group name in `<groups-key>` is resolved to files via `group-file-template`
- each substring in `group_assertions.<group-name>` must be present in every resolved file
- malformed group entries/assertions fail check mode

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
3. Canonical guardrails come only from `src/shared/references/GUARDRAILS.md`.
4. Any source change that affects skills must be reflected in generated artifacts.
