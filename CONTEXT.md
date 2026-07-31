# Rubber Duck Context

## Goals

Rubber Duck optimizes for decision quality over blind automation.

Outcomes:
- developer stays in decision seat
- evidence + questioning improve reasoning
- bounded change reduces rework

## Decisions

**Non-negotiable guardrails**

1. **User decision ownership**
   - no hidden product/architecture decisions
2. **Evidence-first**
   - claims anchored in code/diff/log/tests/constraints
3. **Execution approval gate** (renamed from checkpoint-3/mutating action gate)
   - 6-step blocking workflow: preflight -> approval ask -> wait -> execute -> verify -> scope-change-check
   - explicit "approve" token required (not "continue" / "go ahead")
   - two-tier: semantic changes (full 6-step) vs cosmetic (lightweight confirmation for whitespace/comments/formatting)
4. **Scope limit**
   - scope >2 files must be split first
5. **Safety carve-outs**
   - never weaken trust-boundary validation, security controls, data-loss prevention, accessibility requirements, or explicit user requirements

## Conventions

**Development workflow**

When editing skills or agents:
1. Edit source files in `src/skills/*/` or `src/agents/*/`
2. Rebuild generated artifacts:
   - `make build-skills` -> regenerate `skills/*/` from `src/skills/*/`
   - `make build-agents` -> regenerate `dist/` from `src/agents/*/`
   - `make build` -> rebuild both
3. Verify before commit: `make check`
   - checks guardrails drift, skills assembly, agent artifacts
   - CI requires clean regenerated output

**Build + check contract**

- Skills assembly/check: `scripts/assemble-skills.sh`
- Agent artifact build/check: `scripts/build-harness-artifacts.sh`
- Guardrails drift check: `scripts/check-guardrails-drift.sh`
- `make build` -> skills + agents
- `make check` -> guardrails + skills + agents
- CI workflow: `.github/workflows/check-source-generated-artifacts.yml`
  - split checks (guardrails/skills/agents), path-gated
  - PR check regenerates and requires clean `skills/` + `dist/`

**Interaction model**

- **Request classification**: Simple (≤10 lines code, ≤5 line diffs) handled directly; workflow requests suggest quack with approach choice (conversational vs structured)
- **Routing**: quack skill provides explicit route control; keyword-based precedence (risk/complexity/learning/test/design signals); 33 aliases covering common intents
- **Skill composition patterns**: debug->patch, review->risk->simplify, design->triage, teach->debug
- **Duck Ladder** (minimal-change discipline): 6-rung numbered format (YAGNI -> reuse -> stdlib -> dependency -> shrink -> add)
- Non-mutating analysis: lighter Socratic flow allowed
- Mutating actions: execution approval workflow + explicit "approve" token required
- Clarify-first: ask 1–3 targeted questions when context is incomplete
- Terse by default; expand for security/irreversible risk/user confusion

**Skill routing model**

Skills use three routing patterns:

**Inline-default (4 skills):**
- debug, debt, design, teach
- Governor handles request directly with skill instructions inline
- Lightweight, conversational flow
- Use for: exploratory questioning, read-only analysis, teaching

**Delegated-default (6 skills):**
- patch, refactor, review, risk, simplify, triage
- Governor delegates to fresh skill-specific subagent by default
- Structured workflow, isolated context
- Use for: multi-step processes, complex analysis, workspace-changing actions

**Governor-invoked (2 skills):**
- adapt, grill
- Governor loads skill only when explicitly requested
- Meta-skills for special-purpose tasks
- Use for: skill adaptation, adversarial grilling sessions

**Prompt maintenance guidelines**

- Canonical order: `docs/architecture/04-prompt-order-standard.md`
- Keep prompts schema-first, non-duplicative, explicit on boundaries/handoffs.

**Review output contract (important)**

`duck-review` findings are prefixed one-liners:
- prefix + location + problem + `Fix:`
- Auto-Clarity exception only for security/irreversible-risk comments
- normalize non-compliant finding lines before final output

**Installation model**

- Bash installer: `scripts/rubber-duck.sh`
- PowerShell installer: `scripts/rubber-duck.ps1`
- CLI flags reference: `scripts/README.md`

**Installer maintenance:**
- Keep bash and PowerShell scripts in sync when adding features/flags
- Update `scripts/README.md` CLI reference tables when flags change
- Test both installers with new flags before committing

**Skills install behavior:**
- default global install: `npx skills add <source> -y -g`
- project scope only when explicitly requested (`--project-skills` / `-ProjectSkips`)

**AGENTS.md install behavior:**
- Source file (`AGENTS.md`) has no fences; clean Markdown for version control
- Installer adds `<!-- RUBBER_DUCK_MANAGED_BLOCK START/END -->` fences when installing to user directories
- Skip flags: `--skip-agents-md` (bash) / `-SkipAgentsMd` (PowerShell) skip policy block operations entirely
- Policy block updates: installer detects managed block fences and updates content between them

**AGENTS.md key policies:**
- Mutating action gate applies to assistant-initiated actions only; user-initiated changes expected and normal
- Style guide: anti-repetition rules, Auto-Clarity (expand for security/irreversible risk), terseness (no invented abbreviations, no custom symbols like ->, drop articles/filler)
- Safety carve-outs: never weaken trust-boundary validation, security controls, data-loss prevention, accessibility requirements

**How to verify behavior**

Validation docs:
- `docs/validation/README.md`
- `docs/validation/RUNBOOK.md`
- `docs/validation/CHANGELOG.md`
- Test suite: `docs/validation/test-prompts.json` (21 tests with id/area/prompt/expected_signals/severity/notes)
- Test runner: `scripts/run-validation-tests.sh` (supports --filter/--severity/--interactive)

Quick subset gate (must pass):
- V02, V03, V04, V11, V12, V13, V14
- fail if any Critical/High in subset fails

Note: Test runner is skeleton; requires harness integration for automated execution

**Session handoff expectation**

When changing prompts/policy/tooling:
1. preserve non-negotiable guardrails
2. keep diffs minimal
3. update docs/links if renamed/moved
4. run `make check`

## Glossary

## Deferred-Debt

## Open-Questions

## Session-Log

**2026-07-21:**
- New skill: duck-adapt (meta-skill for external skill adaptation, philosophy compliance auditing, overlap detection)
  - 5 philosophy assets (2,196 lines): philosophy-core.md, socratic-patterns.md, approval-gate-spec.md, adaptation-checklist.md, overlap-patterns.md
- Skill rename: grill-with-ducks -> duck-grill (pattern consistency, 8 chars shorter)
- Enhanced duck-grill: batched questions (up to 3), context threading, pressure calibration, assumption ledger
- AGENTS.md style guide completion: anti-repetition rules, Auto-Clarity definition, terseness rules (no invented abbreviations, no custom symbols)
- AGENTS.md mutating action gate clarification: applies to assistant-initiated actions only; user-initiated changes expected and normal
- Installer feature parity: --skip-agents-md (bash) / -SkipAgentsMd (PowerShell) flags skip AGENTS.md policy block operations
- Documentation: development workflow section, installer sync notes, skills section in README with routing model distinction
- Commits: 46ae62c, 0aa2311, 516981b, 70753cd, da904b6, eff56ad, db819a6, 8ca7179, ed961b7, 9e54571, dbed25d, 2fac809, 2ea3edd

**2026-07-20:**
Comprehensive optimization pass completed:
- UX standardization: prompt-order standard, Duck Ladder 6-rung format, execution approval terminology
- Routing improvements: keyword-based precedence in quack (risk/simplify/teach/triage/design), 76->33 aliases (-57%)
- New skill: duck-refactor (extract/rename/move/inline/pattern-convert; max 5 files; execution approval required)
- Validation framework: 21 tests in docs/validation/test-prompts.json, run-validation-tests.sh script
- Gap closure: 6-step blocking approval workflow, two-tier approval (semantic vs cosmetic), simple-vs-workflow classification
- Composition patterns: debug->patch, review->risk->simplify, design->triage, teach->debug
- Formatting consistency: include directives, asset structure (assets/ vs references/)
- Net: 11 skills (10 duck-* + quack), 2 agents, ~1,200 lines added, ~390 lines removed

**Key commits (optimization pass)**
- 772ac85, d5f1150, ff822ff, f523902, 44049cb, 644c9e4, e7dbc17, 7937c6c, 112052b: UX standardization
- 5865289: checkpoint-3 -> execution approval terminology
- 7937c6c: 6-step blocking workflow
- 73eabc5: simple-vs-workflow boundary
- ed99bd6: routing state flow
- d3f1e92: keyword-based routing precedence
- c41211a: two-tier approval (semantic vs cosmetic)
- 1f8c26a: composition patterns doc
- 4f23787: suggest skill mode (approach choice)
- c44a1e1: validation framework
- f4693bc: duck-refactor skill
- 588da88: formatting consistency pass

## Notes

**Current system shape (source-first)**

- Agent source: `src/agents/<name>/` (`meta.json` + `body.md`)
- Skill source: `src/skills/*/SKILL.md`
  - 13 active skills: duck-adapt, duck-debug, duck-debt, duck-design, duck-grill, duck-patch, duck-refactor, duck-review, duck-risk, duck-simplify, duck-teach, duck-triage, quack
  - Routing model: inline-default (4 skills: debug, debt, design, teach), delegated-default (6 skills: patch, refactor, review, risk, simplify, triage), governor-invoked (2 skills: adapt, grill)
  - Asset structure: `assets/` (runtime, always loaded) vs `references/` (conditional docs)
- Canonical shared guardrails source: `src/shared/references/GUARDRAILS.md`
- Policy snippets: `src/shared/policy-snippets/` (atomic policy fragments for consistency)
- Generated skill artifacts: `skills/*/` (for `npx skills`)
- Generated harness artifacts: `dist/{claude,opencode,copilot}/`
- Global policy: `AGENTS.md`
- Architecture docs: `docs/architecture/`
- Validation suite: `docs/validation/` (test-prompts.json + run-validation-tests.sh)