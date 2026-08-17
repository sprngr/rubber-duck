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
- **Approval wording compacted with non-exhaustive intent note**: execution approval ask uses concise scope prompt with examples while policy clarifies examples are non-exhaustive and clear approval intent is accepted. (date: 2026-08-06)
- **Phase 1 hard constraints adopted**: phase label is stubs/skeleton/interfaces and new-file bootstrap requires stub-first approvals before later implementation phases. (date: 2026-08-06)
- **Validation gate semantics realigned**: V14 now enforces phase-cap boundary, V30 treats clear approval intent as valid, and V32/V33 cover missing phase preflight and phase re-approval. (date: 2026-08-06)
- **Multi-harness install model**: installer accepts a single `--harness`/`-Harness` comma-separated list for multi-target install; legacy single-target flags remain but cannot be combined. Sync spawns child installer processes per enabled target. (date: 2026-08-12)
- **Manifest schema v1 with pins**: `.rubber-duck/manifest.json` tracks `source`, `targets`, and `pins` (sha256 of installed artifacts). Pins are a dev-workflow change log enabling skip-unchanged reinstalls, not a security boundary. (date: 2026-08-12)
- **rawBase allowlist**: installer only accepts sources under `https://raw.githubusercontent.com/sprngr/rubber-duck` unless `--allow-untrusted-source`/`-AllowUntrustedSource` is passed (emits warning). Prevents accidental fork installs. (date: 2026-08-12)
- **Installer runtime dependency floor**: bash installer requires only bash 4+, awk, curl, coreutils. `python3` removed from installer path. (date: 2026-08-12)
- **Single agent architecture**: `rubber-duck` agent body is canonical source of truth for all policy rules. AGENTS.md reduced to version marker. (date: 2026-08-16)
- **duck-policy portable skill**: enforcement rules extracted to `duck-policy` skill, loadable by any agent. Agent body includes skill snippet at build time for progressive disclosure. (date: 2026-08-16)
- **Installer template sources reorganized**: sync wrapper templates moved to `src/install/scripts/`, manifest template moved to `src/install/templates/`. Shared snippets (`src/shared/`) reserved for prompt/policy snippets only. Build outputs at `dist/scripts/` and `dist/templates/`. (date: 2026-08-16)
- **Sync wrapper version check**: sync-latest scripts compare manifest `lastAppliedVersion` against remote/local `VERSION` file before syncing. Prompts user with version change and CHANGELOG link when newer version exists. Fallback templates removed; missing sync template is a hard error. Wrapper forwards the derived raw-base on remote sync; ps1 wrappers use `(Get-Process -Id $PID).Path` for host detection. (date: 2026-08-16)

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

## Deferred-Debt

- TODO(architecture,#22): 2026-08-13 Define localized CONTEXT.md merge model for duck-tape

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

### 2026-08-06 11:15

Policy and validation alignment session completed in bounded approvals.

- Source snippets now enforce phase-fit statement and hard phase-content constraints (stub/skeleton-first for new files).
- Generated skills/dist rebuilt and synced; guardrails drift check passed after AGENTS managed-block sync.
- Validation fixtures/docs updated to V01-V33 with focused calibration of V14/V30/V32/V33; runlog entry added.

### 2026-08-12 22:00

Multi-harness installer branch (`2.1.0-multi-harness-install`) landed:

- Multi-target install via `--harness`/`-Harness` with consolidated output (banner + per-target `[name]` sections + `🦆 quack` footer).
- Manifest schema v1 with `pins` change log (sha256 skip-unchanged optimization).
- rawBase allowlist with `--allow-untrusted-source`/`-AllowUntrustedSource` override.
- Skills install consolidated to a single `npx` call with `-a` per target.
- Bash installer python3 dependency removed (pure-bash manifest library).
- `BASH_SOURCE_URL` renamed to `RUBBER_DUCK_SOURCE_URL`.
- Test coverage parity: bash + PowerShell installer test suites both at 7/7 covering fresh install, reinstall, sync round-trip, allowlist, claude two-file, and dry-run scenarios.

### 2026-08-14

Architecture consolidation:

- Single self-contained `rubber-duck` agent is canonical.
- Stripped `AGENTS.md` to version marker only. Policy content lives in agent body.
- Extracted `duck-policy` portable skill for non-duck agents.
- Validation suite: 44 tests, no variant system.
