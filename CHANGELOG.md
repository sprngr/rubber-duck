# Changelog

All notable changes to Rubber Duck will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed
- Installer policy source now uses built `dist/AGENTS.md` (generated from `src/agents/AGENTS.md`) for local and web installer flows.
- Build rules contracts simplified: removed unenforced keys from `build/agent-assembly.rules.json` and `build/skill-assembly.rules.json` to reduce dead declarative surface.
- Skill assembly coverage expanded: `checks.skill_groups.all_skills` now includes all current source skills, so baseline grouped assertions apply consistently.
- Approval-gate UX lowered friction: semantic execution approval now accepts explicit intent tokens (`approve`, `approved`, `ok`, `go ahead`, `confirm`) instead of strict `approve` only.
- Skill source guardrail alignment updated: `duck-adapt` and `duck-grill` now include shared clarify-first/philosophy snippets to satisfy baseline grouped assertions.
- Execution approval policy now uses phase-gated batching for semantic changes: preflight phase selection (stubs/interfaces, wiring/integration, implementation), adaptive phase caps (6/4/2 files), objective review-fatigue thresholds using changed lines (additions + deletions), and mandatory re-approval between phases. Synced in source policy files and regenerated harness/skill artifacts.

### Fixed
- Installer managed block upsert no longer accumulates extra blank lines above managed fences on repeated runs (bash and PowerShell).
- PowerShell installer now detects script-file execution correctly for `-Source local` and no longer misclassifies it as piped `iwr|iex` mode.
- PowerShell installer local-source file resolution now uses script-scoped variables, fixing null-path failures during local copy.

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
