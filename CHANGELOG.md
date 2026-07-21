# Changelog

All notable changes to Rubber Duck will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

#### Skills
- **duck-adapt** — Meta-skill for external skill adaptation with philosophy compliance auditing and overlap detection
  - 5 philosophy assets (2,196 lines): philosophy-core.md, socratic-patterns.md, approval-gate-spec.md, adaptation-checklist.md, overlap-patterns.md
- **duck-grill** — Deep interrogation with batched questions (up to 3), context threading, pressure calibration, assumption ledger
  - Governor-invoked skill for adversarial design/plan stress-testing
  - Renamed from grill-with-ducks for pattern consistency - inspired by grill-with-docs by [mattpocock](https://github.com/mattpocock/skills/blob/main/skills/engineering/grill-with-docs/SKILL.md)

#### AGENTS.md Policy
- Complete style guide: anti-repetition rules, Auto-Clarity definition, terseness rules
  - No invented abbreviations (cfg/impl/req/res/fn)
  - No custom symbols like → (own token, saves nothing)
  - Drop articles/filler/hedging for directness
- Mutating action gate scope clarification: applies to assistant-initiated actions only; user-initiated changes expected and normal
- Auto-Clarity interaction rule: automatically expand from terse to full explanation when safety requires it (security vulnerabilities, irreversible actions, data-loss risk, severe user confusion)

#### Installer Features
- `--skip-agents-md` / `-SkipAgentsMd` flags for both bash and PowerShell installers
  - Skip AGENTS.md policy block install/update/remove operations
  - Allows skills-only or agents-only installation
- `--branch` / `-Branch` flags for testing non-main branches remotely
  - Auto-detects branch from piped URL (bash only, via `BASH_SOURCE_URL`)
  - Updates `RAW_BASE` and `SKILLS_SOURCE` dynamically
  - Enables: `curl -fsSL https://raw.githubusercontent.com/sprngr/rubber-duck/v2-quackening/scripts/rubber-duck.sh | bash -s -- install --opencode --branch v2-quackening`
- Feature parity between bash and PowerShell installers maintained
- AGENTS.md managed block fencing: source file has no fences (clean Markdown), installer adds fences when installing to user directories

#### Documentation
- Skill routing model documentation: inline-default (4 skills), delegated-default (6 skills), governor-invoked (2 skills)
- Development workflow section in CONTEXT.md
- Installer sync maintenance requirements
- Skills section in README.md with routing model distinction
- CLI reference for skip flags in scripts/README.md

### Changed
- Skill count: 11 → 13 active skills (duck-adapt, duck-grill added)
- Agent architecture: consolidated 6 specialized duckling subagents → single `duckling` delegator with skill-based routing
  - duck-adversary → duck-risk | duck-builder → duck-patch | duck-dry → duck-teach
  - duck-investigator → duck-debug | duck-reviewer → duck-review | duck-simple → duck-simplify
  - duck-explain (v1.0.0 skill) → merged into duck-teach
- Decision-debt marker format simplified: `TODO(decision-debt): <date> <what deferred>` (removed owner/trigger fields)
- Validation terminology: "checkpoint 3 approval gate" → "execution approval gate" (consistent naming)

### Fixed
- Documentation drift between README.md, scripts/README.md, and docs/validation/README.md
- PowerShell installer skill list missing duck-adapt and duck-grill
- RUNBOOK.md skill list outdated (missing 3 skills)

## [v2-optimization-pass] - 2026-07-20

Major optimization pass with validation framework and UX standardization.

### Added
- duck-refactor skill: multi-file restructuring (extract/rename/move/inline/pattern-convert; max 5 files)
- Validation framework: 21 tests in docs/validation/test-prompts.json, run-validation-tests.sh script
- Execution approval terminology (renamed from checkpoint-3/mutating action gate)
- Two-tier approval: semantic changes (full 6-step) vs cosmetic (lightweight confirmation)
- Simple-vs-workflow request classification
- Composition patterns: debug→patch, review→risk→simplify, design→triage, teach→debug

### Changed
- UX standardization: prompt-order standard, Duck Ladder 6-rung format, execution approval terminology
- Routing improvements: keyword-based precedence in quack (risk/simplify/teach/triage/design)
- Alias reduction: 76→33 aliases (-57%)
- Formatting consistency: include directives, asset structure (assets/ vs references/)
- Agent consolidation: pruned 6 specialized duckling subagents (duck-adversary, duck-builder, duck-dry, duck-investigator, duck-reviewer, duck-simple) → unified `duckling` delegator (-1,797 lines)

### Fixed
- Gap closure: 6-step blocking approval workflow enforced
- Review output contract hardened to schema-first format (prefix + location + problem + `Fix:`)

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

## Notes

### Validation Status
- Quick subset (V02, V03, V04, V11, V12, V13, V14): Manual testing recommended before release
- See docs/validation/CHANGELOG.md for detailed validation history

### Upgrade Path
- Fresh install recommended for beta testing
- Skills can be installed globally (`npx skills add https://github.com/sprngr/rubber-duck -y -g`) or project-scoped
- Use `--skip-agents-md` / `-SkipAgentsMd` to preserve existing AGENTS.md customizations

### Breaking Changes
- None expected; additive changes only
- AGENTS.md policy block uses managed fencing (backward compatible)
