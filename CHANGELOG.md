# Changelog

All notable changes to Rubber Duck will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [v3.1.0] - 2026-08-27

### Added

- Session-start hook (opt-in `--session-hook` / `-SessionHook`): deterministically
  causes the `rubber-duck` agent to load the `duck-policy` skill at session start.
  - OpenCode: plugin installed to `.opencode/plugins/session-start.js` registers
    rubber-duck sessions and injects the startup directive into the system prompt
    on every model call (`experimental.chat.system.transform`).
  - Claude Code: scripts installed to `.claude/hooks/` and a `SessionStart` hook
    merged into `.claude/settings.local.json` (idempotent). Fires only when the
    rubber-duck agent is active, detected via hook input `agent_type`.
  - Build emits hook artifacts to `dist/opencode/hooks/` and `dist/claude/hooks/`.
  - Installer (bash + PowerShell parity): install/uninstall of hook artifacts,
    manifest pins, and per-target `sessionHook` tracking replayed on `sync`.
  - The rubber-duck agent body keeps its Enforcement Bootstrap mandate as a
    fallback when the hook is not installed.
  - Copilot support pending (deferred; see plan doc).
- Reviewable-unit decomposition: multi-PR plans must decompose into reviewable units (independent merge, working state after each, explicit ordering + acceptance criteria). Methodology in `src/shared/skill-snippets/reviewable-units.md`; duck-design writes plans as PR sequences; duck-policy Checkpoint 1 gates on decomposition.
- Validation fixture `validation/fixtures/context-loading/src/cache.ts` anchors deferred-debt marker tests to real code.
- Plan decomposition verification spec: `docs/architecture/08-plan-decomposition-verification.md` defines the trigger predicate (explicit multi-PR OR agent-detected size/breadth), gate requirements, and verification acceptance criteria (positive, detection, negative, per-unit content).
- `duck-tidy` extras skill (stub): audit-first cleanup for stale/outdated comments and non-CONTEXT docs. Installed with `--extras` / `-Extras`. Evidence rules: contradicts current code, describes removed behavior, worktree-only add/remove never merged. Carve-outs: TODO markers (duck-debt), ADR/design notes flag-only, CONTEXT.md/.duck-tape (duck-tape). Method bodies pending.
- `duck-adventure` easter-egg skill (manual install): standalone rogue game — multi-turn dungeon crawls with maps, dice combat, random merchants, loot, and achievements tracked across sessions. Fun for its own sake; no handoff to productivity flows.

### Changed

- **Duckling silent-worker contract:** duckling subagent redesigned as single-turn silent worker across all three harnesses (Claude Code, Copilot, OpenCode). Interactive mutating-action-gate include replaced by explicit Silent Worker Contract:
  - one invocation is one turn; no mid-run user dialog
  - never self-approve mutating work
  - `execute` mode produces terminal approval package (preflight + per-file diffs + `Approve this scope?`) instead of mutating the workspace
  - mid-run ambiguity flattens to `## Unresolved questions` block instead of interactive Q&A
  - one phase per invocation; parent orchestrates phase progression
  - tool-unavailable degradation emits explicit `## Tool unavailable` note instead of silent skip
- **Duckling non-delegation list:** duckling refuses `skill_name` of `quack` (routing skill), `duck-tape` (session-memory mutation), and `duck-policy` (session-scoped policy loader). Emits `blocked_recursive_routing` status; parent invokes target skill directly.
- **`DUCKLING_CTX` footer status vocabulary expanded:** added `blocked_awaiting_approval`, `blocked_skill_unavailable`, `blocked_recursive_routing`, `blocked_missing_inputs`, `phase_complete_await_parent`, `degraded_tool_unavailable`. Prior `<ok|blocked>` binary replaced.
- **Rubber-duck Subagent Return Handling:** new agent-body section defining shape-based and status-token-based recognition of subagent returns. Approval packages relayed verbatim as parent's Checkpoint 3 presentation; parent-always-executes rule (subagents propose; parent executes) preserves single-approval-gate invariant. Explicit handlers for phase-progression, blocked-input, and degraded returns.
- **Quack subagent-runbook:** explicit disclaimer that `quack` has no return-side responsibility; parent (`rubber-duck`) owns return handling. Applies to any primary agent that dispatches to duckling.
- **Duckling general contract snippet (`skill-snippets/duckling-general-contract.md`):** behavior rules 4-6 aligned with silent-worker posture. Interactive-dialog contracts (Socratic loops, batched interviews, multi-turn design dialogs) flatten questions to `## Unresolved questions`. Skill-unavailable path emits terminal error instead of interactive question.
- **Duckling harness permission tightening:** silent-worker contract now enforced at harness level in all three harnesses. Duckling tool maps drop mutation tools: Claude `Read, Glob, Grep, Skill`; Copilot `read,search`; OpenCode `edit: deny`, `bash: deny`. Duckling body gains explicit never-call-Edit/Write/Bash rule and parent-always-executes wording. `duck-patch` and `duck-refactor` gain "Subagent execution mode" sections documenting approval-package output under subagent invocation. Permission-tightening spike resolved inline.
- `duck-policy` skill unchanged: portable policy layer stays agent-shape-agnostic; no duckling/quack-specific knowledge added.
- OpenCode plugin uses system-level directive injection (system prompt) instead of
  user-message injection, so the model treats the directive as an instruction
  rather than a suggestion.
- Sync replay fixes a latent off-by-one where extras were matched against the
  install-agents-md flag; extras and the new session-hook flag now map to the
  correct positional arguments.
- Validation suite: 58 tests (V01-V58). V54 covers the Checkpoint 1 plan-decomposition gate; V55 positive trigger, V56 negative non-trigger, V57 per-unit acceptance content, V58 implicit detection trigger extend decomposition coverage via the `rollout` fixture. V25/V26/V38/V54 signals calibrated to observed vocabulary.
- Validation runner now overlays built `skills/` onto `.agents/skills/` in test workspaces, so tests exercise current policy instead of the last installer-synced copy. Resolves false V58 failure caused by stale installed skills.
- duck-policy Method adds gate-sequencing rule: approach-choice, clarify-first, Checkpoint 1 framing, and Checkpoint 2 fire as separate turns; clarify completes before framing. V51 prompt specifies the JWT failure mode so the Checkpoint 2 selection ask is deterministic.
- `docs/architecture/03-adaptive-socratic-policy.md` Checkpoint 1 documents plan decomposition requirement.
- Legacy managed-block migration no longer writes a `.bak.<timestamp>` recovery copy next to `AGENTS.md`/`CLAUDE.md`. The 3.x migration window is closed; the installer strips legacy blocks in place without backup (bash + PowerShell parity).
- Rule wording convention applied across skills, agent bodies, and instruction docs: content-logic rules converted from absolute (always/never/must) to conditional if-then phrasing (~58 rules); structural/spec rules and safety carve-outs retain absolute or refusal form. Convention codified in duck-adapt (`philosophy-core.md` + `adaptation-checklist.md`).
- duck-policy Style: gate ask strings are contract exceptions to terse style — `Confirm or revise?`, `Select an option.`, `Approve this scope?`, `Accept, revise, or rollback?` emitted verbatim at their checkpoints even when otherwise terse. Mitigates intermittent gate compression (V50/V51). Version bump v3.0.1 -> v3.0.2.

### Fixed

- Validation runner: verdict matching evaluates the full multi-turn transcript instead of the final turn only; gate content from earlier turns (V50 Checkpoint 1 framing) no longer yields false negatives.
- Validation tests calibrated to gate sequencing: V08/V25 gained `follow_ups` to advance past approach-choice/clarify-first; V45 steps through approach-choice -> clarify -> evidence -> Checkpoint 1 frame, signals reduced to problem+assumption (options coverage stays with V51).
- Bash installer fails fast with a clear `requires bash 4+` message (and macOS
  `brew install bash` guidance) instead of dying with an obscure
  `declare: -A: invalid option` on bash < 4 (macOS default `/bin/bash` 3.2).

### Known regression

- None active. V51 (Checkpoint 2 selection ask) remains intermittent under flash-class models: the model occasionally ends options mid-list without the verbatim `Select an option.` ask. Mitigations: duck-policy gate-sequencing rule, contract-ask wording in duck-policy Style (v3.0.2), union matcher in the validation runner. V50 (Checkpoint 1 framing) resolved: union matcher surfaces turn-1 framing; contract wording reinforces the ask.

## [v3.0.0] - 2026-08-17

### Added

- `duck-policy` portable skill: enforcement rules (approval gates, safety carve-outs, Duck Ladder, Style, Auto-Clarity, Boundaries, Deferred Debt Markers) extracted to loadable skill for non-duck agents.
- Sync wrapper scripts now check for newer versions before syncing. Compares manifest `lastAppliedVersion` against the remote `VERSION` file (web installs) or local `VERSION` file (local installs). Prompts user with version change and CHANGELOG link when an update is available.
- Installer displays sync update hint after successful install (e.g. `To update: bash .rubber-duck/sync-latest.sh`).
- `RUBBER_DUCK_VERSION` comment embedded in generated sync wrapper scripts for diagnostics.

### Changed

- **Architecture consolidation:** single self-contained `rubber-duck` agent is canonical.
- `AGENTS.md` reduced to version marker only. Policy content lives in agent body.
- Agent body includes `duck-policy` skill snippet at build time (85 lines source, 366 lines rendered).
- Validation suite: 44 tests, variant system removed.
- Build rules updated: agent group assertions check skill-snippet include.
- Sync wrapper version comparison uses POSIX-compatible bash function instead of GNU `sort -V`.
- Installer template sources moved from `src/shared/install-templates/` to `src/install/scripts/` (sync wrappers) and `src/install/templates/` (manifest template). Build outputs remain at `dist/scripts/` and `dist/templates/`.
- Sync wrapper fallback templates removed from both installers. If the sync template cannot be fetched, the installer exits with a clear error instead of silently falling back to an embedded template.
- Sync replay functions deduplicated: bash `sync_replay_install_cmd` + `sync_replay_uninstall_cmd` merged into `sync_replay_cmd`; PowerShell `Get-SyncReplayInstallArgs` + `Get-SyncReplayUninstallArgs` merged into `Get-SyncReplayArgs`.
- Manifest template path extracted to `MANIFEST_TEMPLATE_PATH` constant (bash installer).
- Sync wrapper version check derives the `VERSION` URL from the installer URL (branch/custom raw-base aware) instead of hardcoding `main`.
- Bash installer substitutes sync wrapper tokens via bash parameter expansion — no `sed` or `python3` dependency; portable across GNU and BSD sed environments (macOS).
- Rubber-duck agent bootstrap prose trimmed: rule structure and enforcement teeth preserved; redundant meta-guidance dropped.
- Approval-intent lexicon tightened: a bare option letter (e.g. `B`) with no approval verb is no longer treated as approval. Users must include an approval verb or option-referencing sentence (e.g. `approve`, `Proceed with option B in files X and Y`).

### Removed

- `--policy host|self` flag from both installers.
- `--skip-agents-md` / `-SkipAgentsMd` flag from both installers.
- `--claude-md` / `-ClaudeMd` flag from both installers.
- `--variant` and `--no-agents-policy` flags from validation runner.
- Variant-only validation tests.
- Policy mode installer tests.

### Fixed

- Bash installer: `running_piped()` function definition moved before the sync block that calls it, fixing a function-not-found error when running sync actions.
- CI drift: `*.ps1` line endings standardized to LF in `.gitattributes`; generated `dist/scripts/sync-latest.ps1` now byte-matches rendered output.
- PowerShell sync wrapper host detection: replaced inert `$PSVersionInfo.PSExecutable` (not an automatic variable) with `(Get-Process -Id $PID).Path`.
- Sync wrappers (bash + PowerShell): scope is embedded at install time. User-supplied `--project`/`--global` (bash) or `-Project`/`-Global` (PowerShell) now exits the wrapper with a clear error instead of being silently filtered. Re-run the installer to change scope.
- Sync wrapper now forwards the derived `raw-base` on remote sync, so installs from custom raw-bases/branches replay against the correct source instead of defaulting to `main`.
- Bash sync wrapper version comparison no longer crashes on pre-release version strings (e.g. `v2.3.0-beta`); incomparable versions report "Unable to compare... syncing anyway", matching PowerShell behavior.
- Bash installer `VERSION` file reader now validates format (`^v\d+\.\d+\.\d+$`) matching PowerShell; malformed content no longer poisons manifest state or breaks sync-wrapper version compare.
- Legacy managed policy block migration (3.x upgrade path): installer emits a prominent notice before removing the block and always writes a timestamped `.bak` backup preserving any user content that was inside the block. Fresh installs no longer create spurious `.bak` files when no legacy block exists.
- Installer `doctor` fails fast with a clear message if called before target resolution (previously relied on caller order silently).

## [v2.1.4] - 2026-08-14

### Changed

- Policy/version sync stabilization:
  - aligned repository managed policy block version markers with generated `dist/AGENTS.md`
  - re-synced installer-managed AGENTS policy content to remove guardrails drift between root `AGENTS.md` managed block and built policy artifact
  - preserved managed-block source contract (`src/agents/AGENTS.md` -> `dist/AGENTS.md` -> installer-managed target files)


## [v2.1.3] - 2026-08-14

### Changed

- quack routing language is now harness-agnostic for delegated execution:
  - replaced OpenCode-specific `task` wording with generic subagent dispatch wording in source and generated skill artifacts
  - preserves existing routing behavior while removing tool-name coupling from skill text
- quack skill metadata version bumped to `v2.1.3` in source-of-truth and regenerated artifact.
- duck-grill close-out contract now aligns with duck-tape compaction expectations:
  - added deterministic interoperability fields (`Decision`, `Assumptions ledger` status lines, deferred debt markers, position seed, `compact-ready`)
  - added explicit follow-up prompt when compaction is ready (`Run duck-tape merge now?`)
- duck-grill CONTEXT template now uses duck-tape schema-aligned section shape:
  - `Contents`, `Goals`, `Decisions`, `Conventions`, `Glossary`, `Deferred-Debt`, `Open-Questions`, `Notes`
  - glossary entries retain richer domain metadata (`Code`, `Scope`, `Aliases`, `Avoid`)
  - location guidance now sets canonical path to root `CONTEXT.md`
- Project context debt tracking updated with linked spike marker:
  - `TODO(architecture,#22): 2026-08-13 Define localized CONTEXT.md merge model for duck-tape`

## [v2.1.2] - 2026-08-13

### Changed

- duck-tape skill metadata version bumped to `v2.1.2` in source-of-truth (`src/skills/duck-tape/SKILL.md`) and regenerated artifact.
- duck-tape Claude hook install guidance now offers repo-local `.claude/settings.local.json` (recommended) or `.claude/settings.json` for hook merge placement.
- duck-tape Claude troubleshooting guidance now validates either `.claude/settings.local.json` (recommended) or `.claude/settings.json`.
- README quick start now includes basic manifest update command: `./scripts/rubber-duck.sh sync --project`.
- Edited skills aligned to current project version `v2.1.2` (`duck-tape`, `duck-adapt`, `quack`) in source and regenerated artifacts.

### Fixed

- Clarified Claude hook setup docs to match repo-local config workflow and reduce confusion between shared and local settings targets.
- Distributed skill references now use `.agents/skills/...` instead of source-tree `src/skills/...` in duck-tape hooks/docs and duck-adapt skill guidance.
- Harness artifact renderer now resolves `{{include: skill-snippets/...}}` in agent bodies, eliminating raw include tokens in rendered duckling dist agents.
- Quack skill boundaries now render safety carve-out snippet correctly (no leaked include token in built skill output).

### Security

- duck-tape opencode plugin transcript snapshot now redacts recursively before serialization to `.duck-tape/<id>-transcript.json` (prevents raw secret leakage in recovery snapshots).
- Expanded duck-tape redaction coverage across shell, PowerShell, and opencode plugin extract paths:
  - password/passwd/pwd/secret/token/client_secret/private_key key-value forms
  - credentialed connection URIs (`scheme://user:pass@host`)
  - secret-like environment assignments (`...PASSWORD=...`, `...TOKEN=...`, etc.)
  - baseline PII shapes (email, phone, SSN)

## [v2.1.1] - 2026-08-13

### Changed

- duck-tape security hardening across source and generated hook/plugin artifacts:
  - Removed PowerShell `-ExecutionPolicy Bypass` from hook commands and added non-interactive/no-profile shell flags.
  - Added transcript trust-boundary checks (symlink reject, trusted-root enforcement, size cap via `DUCK_TAPE_MAX_TRANSCRIPT_BYTES`, fail-closed fallback) in shell/PowerShell hook scripts.
  - Added sensitive-token redaction for extracted state and raw transcript outputs (shell, PowerShell, and opencode plugin paths).
  - Hardened opencode plugin transcript snapshot handling with payload size cap and `.duck-tape` path validation.
- duck-debt prompt-injection posture hardening:
  - Added explicit untrusted-content handling rules in skill method/output guidance (treat scanned repository text as data, never instructions; no execution/follow actions; sanitized output snippets only).

### Security

- Reduced indirect prompt-injection and data-exposure risk in transcript/debt scanning flows while preserving existing feature behavior.

## [v2.1.0] - 2026-08-12

### Changed

- Installer policy source now uses built `dist/AGENTS.md` (generated from `src/agents/AGENTS.md`) for local and web installer flows.
- Build rules contracts simplified: removed unenforced keys from `build/agent-assembly.rules.json` and `build/skill-assembly.rules.json` to reduce dead declarative surface.
- Skill assembly coverage expanded: `checks.skill_groups.all_skills` now includes all current source skills, so baseline grouped assertions apply consistently.
- Approval-gate UX lowered friction: semantic execution approval now accepts explicit intent tokens (`approve`, `approved`, `ok`, `go ahead`, `confirm`) instead of strict `approve` only.
- Approval ask copy is now compact and explicit: `Approve this scope? (examples: approve/ok/confirm)`.
- Approval intent examples are now explicitly non-exhaustive; any clear approval intent is accepted.
- Skill source guardrail alignment updated: `duck-adapt` and `duck-grill` now include shared clarify-first/philosophy snippets to satisfy baseline grouped assertions.
- Execution approval policy now uses phase-gated batching for semantic changes: preflight phase selection (stubs/interfaces, wiring/integration, implementation), adaptive phase caps (6/4/2 files), objective review-fatigue thresholds using changed lines (additions + deletions), and mandatory re-approval between phases. Synced in source policy files and regenerated harness/skill artifacts.
- Phase terminology now uses `stubs/skeleton/interfaces` and scope policy adds hard phase-content constraints plus a new-file bootstrap rule (stub/skeleton first, implementation in later phases) to prevent oversized first-pass diffs.
- Cross-skill policy consistency pass updated skill assets/runbooks/evals to remove fixed file-count gating and align mutating workflows to phase-gated execution approval (phase selection, adaptive caps, objective review-fatigue triggers, and re-approval between phases), including regenerated `skills/*` and `dist/*` artifacts.
- Local pre-commit hook now runs `markdownlint-cli2` with broad markdown coverage and a pragmatic rule profile (`.markdownlint-cli2.yaml`) to enforce hygiene-first lint checks without blocking on full style normalization.
- Assembly renderers now support nested embedded `{{include: ...}}` expansion in both skills and harness build pipelines.
- Assembly rules now assert approval-workflow snippet presence and include wiring to catch drift early.
- Validation suite alignment: V14 now checks phase-cap boundary (not stale file-count premise), V30 reflects clear approval intent handling, and new V32/V33 cover missing phase selection preflight and re-approval between phases. Validation docs/context/runlog updated to V01-V33.
- duck-tape session-id handling hardened: `/duck-tape` and `/duck-tape merge` now auto-generate `<YYYY-MM-DD-HHMM>` by default, ask only for explicit custom IDs, and issue one corrective prompt for invalid custom IDs.
- Guardrails drift check now fails if any rendered `dist/**/*.md` artifact contains duplicate headings (markdown ATX `#`/`##`/... or bold `**...**` pseudo-headers) within a single file. Catches nested-include composition regressions where the same policy snippet gets rendered twice.\
- Execution approval policy now treats documentation/planning edits as semantic changes by default (same bounded preflight/diff/approval flow as code), while keeping typo-only fixes in non-code text files as cosmetic lightweight confirmations.
- Policy source, architecture policy doc, and skill guardrail references were aligned to the same docs-as-semantic rule with the typo-only exception.
- Validation suite expanded and calibrated for this policy:
  - Added V34 (documentation/planning semantic gate) and V35 (typo-only cosmetic exception).
  - Updated validation fixture `rollout` ADR typo seed and matcher signals for stable behavior checks.
  - Updated validation docs/context metadata from V01-V33 to V01-V35.
- Installer CLIs now require explicit harness target selection. Bash requires exactly one of `--opencode`, `--copilot`, `--claude`. PowerShell requires exactly one of `-OpenCode`, `-Copilot`, `-Claude`.
- Installer CLIs now reject conflicting scope flags (`--project` + `--global`, `-Project` + `-Global`) for consistent cross-shell behavior.
- Installer docs updated to reflect explicit target requirement and target/scope constraints in `scripts/README.md`.
- Add versioning flag to embed into skills and AGENTS policy, keeping it in sync back to the release.
- Installer parity pass expanded PowerShell behavior to match Bash for dry-run workflows:
  - Added `-DryRun` support across mutating installer paths (backup, managed-block upsert/remove, agent install/uninstall, skills install/uninstall, doctor directory creation, manifest updates).
  - Sync recursion now propagates dry-run and relevant installer flags to nested install/uninstall calls.
- Branch-selection parity improved across shells:
  - PowerShell now auto-detects non-`main` branch from raw GitHub URL context (`BASH_SOURCE_URL`) when `-Branch` remains default `main`, mirroring Bash branch-detection intent.
- Installer CLI reference docs (`scripts/README.md`) were aligned with current behavior:
  - Added/updated `sync`, harness selector (`--harness` / `-Harness`), prune (`--prune` / `-Prune`), and dry-run (`--dry-run` / `-DryRun`) coverage.
  - Updated target-selection constraints to reflect harness-list mode, legacy single-target mode, and no-mixing rules.
  - Documented manifest-driven sync behavior and manifest paths for project/global scope.
- Installer multi-target install now supports a single `--harness`/`-Harness` comma-separated list. Consolidated output: one banner + version + source + doctor + skills header, per-target `[name]` section, single `🦆 quack` footer.
- Bash installer no longer requires `python3`. Manifest parsing/emission is pure bash via a small library (`manifest_load`/`manifest_save` populating `MF_*` globals). PowerShell installer already used native JSON.
- Skills install consolidated: a single `npx` call receives one `-a <agent>` flag per selected target, replacing per-target `npx` invocations.
- Pinning reframed as a dev-workflow change log with skip-unchanged optimization (not a security boundary). Fresh install writes `pins`; re-install compares fetched artifact sha256 to on-disk and skips rewriting unchanged files (preserves mtime).
- Environment variable renamed `BASH_SOURCE_URL` -> `RUBBER_DUCK_SOURCE_URL` for shell-agnostic naming; both installers respect it for auto branch detection from piped install URLs.
- Installer backup retention: only the most recent `<file>.bak.*` is kept per policy file. Prior backups are pruned on install/uninstall. Applies to both bash and PowerShell installers.

#### Skills

- Skill metadata version format now matches `RUBBER_DUCK_VERSION` style (unquoted `vX.Y.Z`): `version` changed from `"2.0"` to `v2.0.0` for `duck-adapt`, `duck-debt`, `duck-debug`, `duck-design`, `duck-grill`, `duck-patch`, `duck-refactor`, `duck-review`, `duck-risk`, `duck-simplify`, `duck-tape`, `duck-teach`, `duck-triage`, and `quack`.
- Fix confusing instructions causing `quack` to stall after routing.

### Added

- Installer canonical-source guardrail: `rawBase` defaults to the canonical prefix `https://raw.githubusercontent.com/sprngr/rubber-duck` to avoid accidentally installing from a fork or mistyped URL. Override with `--allow-untrusted-source` / `-AllowUntrustedSource` (emits warning) when installing from a fork or mirror. Applies to both `install` and `sync` paths.
- Installer SHA-256 artifact record + skip-unchanged install: `install` writes a `pins` block into the manifest recording the hash of each installed agent file. Subsequent installs compare fetched artifacts against the destination and skip rewriting files that already match (preserving mtime and speeding up reinstalls). Pins are refreshed after each install to reflect current disk state.
- Installer downgrade warning: emits `WARN: downgrade: manifest lastAppliedVersion X > incoming Y` when installing an older release than the manifest records. Warning only; does not block the install.
- Installer test suite (`tests/run-installer.sh`, `make check-installer`) covering fresh install, reinstall pin verify, pin tamper mismatch, sync install-then-prune round-trip, and rawBase allowlist scenarios in isolated tmp workspaces.
- PowerShell installer test suite (`tests/run-installer.ps1`, `make check-installer-ps`) mirrors the bash suite: fresh install, reinstall pin verify, sync round-trip, rawBase allowlist, claude two-file layout, and dry-run scenarios.
- Bash dry-run test cases (`dry-run no writes`, `dry-run multi-target layout`) added to `tests/run-installer.sh`.

### Fixed

- Installer `--raw-base` (bash) CLI flag was silently overwritten by the branch-derived default. Now respected when provided.
- PowerShell installer `sync -Prune` returned early when the manifest had no enabled targets, skipping the prune loop entirely. Now falls through to prune (parity with bash).
- PowerShell installer `sync` threw on empty or malformed manifest instead of falling back to an empty state. Now recovers and reports `sync: no enabled targets in manifest`.
- PowerShell installer security helpers (`Test-RawBaseAllowed`, `Get-Sha256`, and related) were defined inside `function rubber-duck` after the sync path's call sites. PS does not hoist nested function definitions, so the sync-path `rawBase` allowlist check was silently bypassed. Helpers hoisted to script scope; sync now correctly enforces the allowlist.
- Bash installer `sync` install loop under `set -u` errored on an empty enabled-targets array on bash 3.2 (macOS default). Guarded with array-length check.
- `.gitignore` narrowed from `*.bak.*` to `*AGENTS.md.bak.*` / `*CLAUDE.md.bak.*` to avoid masking unrelated backup files (editor, other tools).
- Installer managed block upsert no longer accumulates extra blank lines above managed fences on repeated runs (bash and PowerShell).
- PowerShell installer now detects script-file execution correctly for `-Source local` and no longer misclassifies it as piped `iwr|iex` mode.
- PowerShell installer local-source file resolution now uses script-scoped variables, fixing null-path failures during local copy.
- duck-tape hook JS behavioral test normalization now accepts compact stamp format (`YYYY-MM-DD-HHmm`) in state/marker assertions, and timestamp/stamp consistency parsing now accepts compact and separated minute formats. This removes false failures in `check-hooks-behavior`.
- Nested include expansion no longer injects extra blank lines in generated markdown artifacts.
- Rendered rubber-duck agent artifacts (`dist/*/agents/rubber-duck.md`) no longer duplicate the approval-workflow, scope-rules, and change-type sections. `src/agents/rubber-duck/body.md` no longer re-includes policy snippets that are already pulled in via the Safety Gates section.
- AGENTS.md Layout section now correctly distinguishes `.github/` (tracked CI/workflow config) from `.agents/`, `.claude/`, `.opencode/` (untracked local harness install targets, populated by installers).
- PowerShell installer target-resolution fallback no longer defaults implicitly to global opencode paths.
- Installer `write_pins` (bash) and `Write-Pins` (PowerShell) did not honor dry-run. Bash silently wrote `.rubber-duck/manifest.json`; PowerShell errored on missing parent directory. Both now emit a `[dry-run] pins update -> <path>` marker and skip the write.

## [v2.0.1] - 2026-08-03

Patch release: duck-tape opencode plugin hook hardening.

### Fixed

- Path traversal in `opencode.plugin.js` — strict `sessionId` charset validation (alphanumeric + hyphen, max 128 chars) before filename construction
- Windows filename safety — stamp format changed from `HH:MM` to `HHMM` (colon stripped) matching skill's `<YYYY-MM-DD-HHMM>` session ID format
- Rotation off-by-one — cap now enforces 10 total state files (was allowing 11); eviction precedence auto, then recovered, then manual
- Rotation comment aligned with actual behavior
- Tests: `sessionId` traversal guard, extraction edge cases (`<`-prefixed user text skip, multiple DECISION_PATTERN variants, `lastText` assignment, null-info guards)

- **Full Changelog**: [v2.0.0...v2.0.1](https://github.com/sprngr/rubber-duck/compare/v2.0.0...v2.0.1)

## [v2.0.0] - 2026-08-02

Major release: validation framework, UX standardization, agent consolidation, new skills, installer features, and documentation refinement.

### Added

#### Skills

- **duck-refactor** — Multi-file restructuring (extract/rename/move/inline/pattern-convert; max 5 files)
- **duck-adapt** — Meta-skill for external skill adaptation with philosophy compliance auditing and overlap detection
  - 5 philosophy assets (2,196 lines): philosophy-core.md, socratic-patterns.md, approval-gate-spec.md, adaptation-checklist.md, overlap-patterns.md
- **duck-grill** — Deep interrogation with batched questions (up to 3), context threading, pressure calibration, assumption ledger
  - Governor-invoked skill for adversarial design/plan stress-testing
  - Renamed from grill-with-ducks for pattern consistency - inspired by grill-with-docs by [mattpocock](https://github.com/mattpocock/skills/blob/main/skills/engineering/grill-with-docs/SKILL.md)

#### Policy + Workflow

- Validation framework: 21 tests in docs/validation/test-prompts.json, run-validation-tests.sh script
- Two-tier approval: semantic changes (full 6-step) vs cosmetic (lightweight confirmation)
- Simple-vs-workflow request classification
- Composition patterns: debug->patch, review->risk->simplify, design->triage, teach->debug
- Complete AGENTS.md style guide: anti-repetition rules, Auto-Clarity definition, terseness rules
  - No invented abbreviations (cfg/impl/req/res/fn)
  - No custom symbols like -> (can cause issues in code, same token value as unicode arrow, saves nothing)
  - Drop articles/filler/hedging for directness
- Auto-Clarity interaction rule: automatically expand from terse to full explanation when safety requires it (security vulnerabilities, irreversible actions, data-loss risk, severe user confusion)
- 4-checkpoint decision policy: problem framing, solution selection, execution approval, acceptance

#### Installer Features

- `--skip-agents-md` / `-SkipAgentsMd` flags for both bash and PowerShell installers
  - Skip AGENTS.md policy block install/update/remove operations
  - Allows skills-only or agents-only installation
- `--branch` / `-Branch` flags for testing non-main branches remotely
  - Auto-detects branch from piped URL (bash only, via `BASH_SOURCE_URL`)
  - Updates `RAW_BASE` and `SKILLS_SOURCE` dynamically
- `--extras` / `-Extras` flags for optional extras skills (duck-adapt, duck-grill, duck-tape)
- Feature parity between bash and PowerShell installers maintained
- AGENTS.md managed block fencing: source file has no fences (clean Markdown), installer adds fences when installing to user directories

#### Documentation

- Skill routing model documentation: inline-default (4 skills), delegated-default (6 skills), governor-invoked (2 skills)
- Architecture docs: philosophy, agent-skill model, adaptive Socratic policy, prompt order standard, harness config, skill assembly contract, skill asset convention
- `CONTRIBUTING.md` — build/check/validation workflow, conventions, issue tracker link
- `validation/CONTEXT.md` — validation-specific context (purpose, structure, pass rate state, calibration approach)
- Best practices doc: docs/best-practices.md
- Validation docs consolidated: README.md (test suite + runbook + smokecheck), test-prompts.json
- Mermaid routing diagram in README
- Development workflow section in CONTEXT.md
- CLI reference in scripts/README.md

### Changed

- Skill count: 11 -> 13 active skills (duck-adapt, duck-grill added)
- Agent architecture: consolidated 6 specialized duckling subagents -> single `duckling` delegator with skill-based routing (-1,797 lines)
  - duck-adversary -> duck-risk | duck-builder -> duck-patch | duck-dry -> duck-teach
  - duck-investigator -> duck-debug | duck-reviewer -> duck-review | duck-simple -> duck-simplify
  - duck-explain (v1.0.0 skill) -> merged into duck-teach
- UX standardization: prompt-order standard, Duck Ladder 6-rung format, execution approval terminology
- Routing improvements: keyword-based precedence in quack (risk/simplify/teach/triage/design)
- Alias reduction: 76->33 aliases (-57%)
- Decision-debt marker format simplified: `TODO(decision-debt): <date> <what deferred>` (removed owner/trigger fields)
- Validation terminology: "checkpoint 3 approval gate" -> "execution approval gate" (consistent naming)
- Formatting consistency: include directives, asset structure (assets/ vs references/)
- README restructure: overview-first, install one-liners, links to docs/ for depth
- CONTEXT.md prune: session logs and re-derivations moved out, TOC added, glossary trimmed
- Architecture docs: inline restatements replaced with cross-links
- Validation suite hoisted from `docs/validation/` to top-level `validation/` — reflects expanded scope beyond documentation (executable runner, fixtures, multi-turn tests, bwrap sandbox)
- Test runner moved from `scripts/run-validation-tests.py` to `validation/run-validation-tests.py`
- Skill descriptions optimized across 9 skills — token trim, body alignment, subcommands/modes lines, alias collision fix (duck-grill "grill me" -> "grill this")
- Routing diagram in README revised — approval gate placed after skill proposal, "no" branch loops to governor for revision, single SKILL node
- duck-tape rotation notes no longer persisted to CONTEXT.md — working-memory metadata only (removed from SCHEMA.md, OUTPUT_SCHEMA.md, STATE_SCHEMA.md, examples, CHANGELOG)
- duck-tape merge drops resolved Open-Questions instead of retaining them — resolution content already captured in Decisions or Notes

### Fixed

- Documentation drift between README.md, scripts/README.md, and docs/validation/README.md
- PowerShell installer skill list missing duck-adapt and duck-grill
- RUNBOOK.md skill list outdated (missing 3 skills)
- Gap closure: 6-step blocking approval workflow enforced
- Review output contract hardened to schema-first format (prefix + location + problem + `Fix:`)
- Stale links in MANUAL.md pointing to installed copy instead of source
- Stale validation doc references after consolidation

### Removed

- docs/validation/CHANGELOG.md (folded into main CHANGELOG Validation section)
- docs/validation/RUNBOOK.md (folded into docs/validation/README.md Runbook section)
- docs/validation/quack-smokecheck.md (folded into docs/validation/README.md Quack runtime smokecheck section)
- docs/architecture/07 "Migration from old structure" section (migration complete, no ongoing value)
- CONTEXT.md Session-Log entries and Re-derivation blocks (moved to .duck-tape state files)

### Breaking Changes

- None expected; additive changes only
- AGENTS.md policy block uses managed fencing (backward compatible)

**Full Changelog**: [v1.1.0...v2.0.0](https://github.com/sprngr/rubber-duck/compare/v1.1.0...v2.0.0)

## [v1.1.0] - 2024-07-17

Released v1.1 with optimizations & tweaks ([#8](https://github.com/sprngr/rubber-duck/pull/8))

### Added

- Build system to share reused strings between skills and agents
- Deferred marker inclusion rule to core AGENTS.md

### Changed

- Compacted prose for token usage, removed redundant rules
- Reorganized skills and agents for rules loading order

### Fixed

- duck-debt to be deferred marker agnostic (TODO/FIXME/HACK/XXX)

**Full Changelog**: [v1.0.0...v1.1.0](https://github.com/sprngr/rubber-duck/compare/v1.0.0...v1.1.0)

## [v1.0.0] - 2024-07-03

Initial stable release.

### Added

- Initial installer version (bash & PowerShell) + harness artifact build system
- Basic harness support: Claude Code, Copilot CLI & VS Code, OpenCode
- Agents: rubber-duck (main/router)
- Duckling subagents: duck-adversary, duck-builder, duck-dry, duck-investigator, duck-reviewer, duck-simple
- Skills: duck-debt, duck-debug, duck-design, duck-explain, duck-review, duck-teach, duck-triage
- Core Rubber Duck philosophy documentation

**Full Changelog**: [https://github.com/sprngr/rubber-duck/commits/v1.0.0](https://github.com/sprngr/rubber-duck/commits/v1.0.0)

---

Validation run log: [validation/RUNLOG.md](./validation/RUNLOG.md)
