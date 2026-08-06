# Rubber Duck Context

## Contents

- [Goals](#goals)
- [Decisions](#decisions)
- [Conventions](#conventions)
- [Glossary](#glossary)
- [Deferred-Debt](#deferred-debt)
- [Open-Questions](#open-questions)
- [Notes](#notes)

## Goals

- **Decision quality over automation**: optimize for reasoning quality, not silent execution.
- **Developer decision ownership**: keep product and architecture decisions with user.
- **Bounded safe change**: use minimal diffs with explicit verification.

## Decisions

- **Policy authority split**: `AGENTS.md` is behavioral policy source of truth. `CONTEXT.md` stores project memory and decision history only. (date: 2026-08-04)
- **Execution approval model updated**: explicit approval intent is required for assistant-initiated semantic changes; accepted intents are `approve`, `approved`, `ok`, `go ahead`, `confirm`, with bounded semantic scope unchanged. Procedural details live in `AGENTS.md`. (date: 2026-08-05)
- **Diff format rule adopted**: existing files use unified diff; new files use full-content block; one file per block. Canonical examples are in `src/shared/references/diff-format-examples.md`. (date: 2026-08-01)
- **Installer skill-set split**: default 11 skills + optional extras 3 (`duck-adapt`, `duck-grill`, `duck-tape`); uninstall removes all 14 to prevent orphans; status reports extras separately. (date: 2026-08-01)
- **Validation suite expansion**: prompt validation moved to top-level `validation/` with fixtures and multi-turn coverage. (date: 2026-08-02)
- **Validation baseline metrics captured**: suite size 31; best observed pass 23/31 (74%); typical range 18-23/31 due to wording variance; stable subset gate retained. (date: 2026-08-02)
- **Installer policy source move**: installer policy source moved from repo-root `AGENTS.md` to built `dist/AGENTS.md`; source policy content comes from `src/agents/AGENTS.md`. (date: 2026-08-04)
- **Assembly rules contract trimmed**: removed unenforced declarative keys from `build/agent-assembly.rules.json` and `build/skill-assembly.rules.json`; retained only actively enforced checks/invariants to reduce false-confidence surface. (date: 2026-08-05)
- **Skill baseline assertion coverage expanded**: `build/skill-assembly.rules.json` `checks.skill_groups.all_skills` now covers all current source skills so baseline grouped assertions apply consistently. (date: 2026-08-05)
- **Installer idempotence fix**: installer upsert no longer accumulates blank lines above managed block fences on repeated runs (bash + PowerShell). (date: 2026-08-04)
- **PowerShell local-source fixes**: corrected script-file path detection and local-source variable scoping to prevent false piped-mode and null-path errors. (date: 2026-08-04)
- **duck-tape recovery model**: Angle A/B model kept with auto pre-compact extraction and LLM-assisted resume synthesis; state rotation uses auto -> recovered -> manual eviction precedence with max 10 files. (date: 2026-08-01)

## Conventions

- **Source-first edits**: edit `src/*` files first; generated outputs are `skills/*` and `dist/*`.
- **Build/check contract**: run `make build` after source edits and `make check` before commit.
- **Installer parity**: keep `scripts/rubber-duck.sh` and `scripts/rubber-duck.ps1` functionally aligned for shared flags/behavior.
- **Installer policy source**: local and web installer flows consume built `dist/AGENTS.md`.
- **Routing model**: simple requests can stay conversational; workflow requests can route via `quack`.
- **Skill routing classes**: inline-default (debug, debt, design, teach), delegated-default (patch, refactor, review, risk, simplify, triage), governor-invoked (adapt, grill), router-only (quack).
- **Skill composition patterns**: debug->patch, review->risk->simplify, design->triage, teach->debug.
- **Validation entrypoint**: primary runner is `python3 validation/run-validation-tests.py`.
- **Policy text changes**: when policy snippets change, regenerate artifacts and verify drift checks.

## Glossary

- **Source-of-truth tree**: `src/` files are edited directly; `skills/` and `dist/` are generated outputs.
- **Policy block fences**: `<!-- RUBBER_DUCK_MANAGED_BLOCK START -->` and `<!-- RUBBER_DUCK_MANAGED_BLOCK END -->` delimit installer-managed sections in target files.
- **Diff format selection rule**: file existence determines diff format (unified diff for existing files, full-content block for new files).
- **Default skills set**: 11 skills from `.claude-plugin/plugin.json`.
- **Extras skills set**: `duck-adapt`, `duck-grill`, `duck-tape`, installed only with extras flags.
- **Validation fixtures**: scenario clusters live under `validation/fixtures/` for prompt-eval coverage.
- **Guardrails drift check**: `scripts/check-guardrails-drift.sh` verifies vendored guardrails alignment.
- **Bash-only dry-run**: `scripts/rubber-duck.sh` supports `--dry-run`; `scripts/rubber-duck.ps1` has no `-DryRun`.

## Deferred-Debt

- None recorded.

## Open-Questions

- None active.

## Notes

### 2026-08-02 14:30

Current system shape snapshot:

- Agent source: `src/agents/<name>/` (`meta.json` + `body.md`)
- Skill source: `src/skills/*/SKILL.md` (14 active skills)
- Generated artifacts: `skills/*/` and `dist/{claude,opencode,copilot}/`
- Shared policy/skill snippets: `src/shared/policy-snippets/*`, `src/shared/skill-snippets/*`
- Validation suite: `validation/` with prompts, fixtures, and runner

### 2026-08-02 23:35

Validation expansion and prompt/skill refinements landed. Validation remained volatile due to wording sensitivity, with stable subset coverage retained.

- Baseline metrics: 31 total tests, best 23/31 (74%), typical 18-23/31.

### 2026-08-04 21:45

Installer and policy-source updates:

- Built `dist/AGENTS.md` now generated from `src/agents/AGENTS.md`.
- Installers use `dist/AGENTS.md` as policy source in local and web flows.
- Managed-block insertion idempotence fixed for bash and PowerShell.
- PowerShell `-Source local` execution/path handling fixed.
