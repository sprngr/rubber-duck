# Changelog

All notable changes to Rubber Duck will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

## Validation

Track validation outcomes across commits/releases.

**Entry policy:**
- Primary gate: quick subset (`V02, V03, V04, V11, V12, V13, V14`).
- Record all quick-subset failures always.
- If any extended checks fail, record those IDs too.
- Verdict rule: FAIL if any Critical/High in quick subset fails.

**Entry template:**

```md
## YYYY-MM-DD — <branch or release tag>

- Commit: <sha>
- Runner: <name/handle>
- Suite version: docs/validation/README.md
- Verdict: PASS | FAIL

### Quick subset
- Passed: <ids>
- Failed: <ids or none>

### Extended failures (optional)
- Failed: <ids or none>

### Notes
- <short regression summary>
- <root cause or follow-up issue>
```

### 2026-07-21 — v2-quackening

- Verdict: not run (development session)
- Session work: AGENTS.md style guide, mutating action gate scope clarification, installer feature parity, duck-adapt + duck-grill skills, routing model docs
- No validation run performed; changes primarily documentation and installer tooling

### 2026-06-29 — overfit-cleanup-pass

- Verdict: PASS
- Quick subset: V02, V03, V04, V11, V12, V13, V14 passed
- Overfit cleanup pass applied across governor/router-era prompts and ducklings/skills with adaptive strictness for non-mutating analysis
- V14 boundary reinforced: explicit split required for scope >2 files
- Review output contract hardened to schema-first format
- V03 formatting regression resolved after adding schema hint + negative->positive formatting examples

Full validation history: see git log for `docs/validation/CHANGELOG.md` (file deleted in this refactor; history preserved in git).

## Notes

### Validation Status
- Quick subset (V02, V03, V04, V11, V12, V13, V14): Manual testing recommended before release
- Validation entries recorded in the Validation section above

### Upgrade Path
- Fresh install recommended for beta testing
- Skills can be installed globally (`npx skills add https://github.com/sprngr/rubber-duck -y -g`) or project-scoped
- Use `--skip-agents-md` / `-SkipAgentsMd` to preserve existing AGENTS.md customizations

### Breaking Changes
- None expected; additive changes only
- AGENTS.md policy block uses managed fencing (backward compatible)
