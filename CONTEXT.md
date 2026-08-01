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

**duck-tape Angle A/B** (date: 2026-08-01)

- **Angle A auto-checkpoint**: pre-compact hook extracts state from transcript (Claude Code, Copilot) or SDK (opencode) before compaction. Replaces manual checkpoint requirement for compaction recovery.
- **Angle B LLM-assisted recovery**: `/duck-tape resume` runs `extract-raw.sh`/`.ps1` on transcript, LLM synthesizes `-recovered.state.md` with semantic decision extraction. Higher fidelity than pattern-matched auto state.
- **Three-tier eviction precedence**: auto dropped first (oldest auto), then recovered, then manual. Max 10 state files in `.duck-tape/`.
- **Drop auto-compact opt-in**: removed `/duck-tape auto on/off`, `.duck-tape/auto` marker, threshold triggers, standing-approval. Angle A/B pre-compact hooks fire automatically.
- **Sync installed copy from built `skills/`**: installed `~/.agents/skills/duck-tape/` synced from built `skills/duck-tape/` not `src/`. `src/` has unresolved `{{include}}` directives.
- **Angle B recovery validated end-to-end**: `/duck-tape resume` wrote `-recovered.state.md` from real transcript via extract-raw + LLM synthesis.

**duck-tape hook review fixes** (date: 2026-08-01)

- **PowerShell port bug fixes**: dedup before tail-10, null-guard data.content before StartsWith, re-query $all in rotation else-branch. Parity with bash/JS ports fixed in db039dd.
- **JS Date nit fix**: hoist new Date() to single instance in opencode.plugin.js so timestamp and stamp cannot cross minute boundary.
- **Behavioral test suite**: golden-file tests via bash + node, no framework dependency. 16 assertions covering extract-state.sh, extract-raw.sh, opencode.plugin.js. CI job check-hooks-behavior added.
- **Rotation eviction excludes just-written file**: fresh checkpoint survives rotation. Eviction picks oldest of remaining candidates instead of the file just written.

**Approval gate step update** (date: 2026-08-01)

- **Step 2 reworded**: "Present list of changes broken down by file" -> "Present list of changes broken down by file as formatted diff". Propagated to all consumers of mutating-action-gate policy snippet.

**Approval gate diff format spec** (date: 2026-08-01)

- **Hybrid format**: unified diff (`---`/`+++`/`@@` hunks, `-`/`+` prefixes) for edits to existing files; full content in fenced code block with file path header for new files. One file per diff block.
- **Deterministic condition**: file existence selects format. No model interpretation, no classification ambiguity.
- **Propagation**: snippet `src/shared/policy-snippets/mutating-action-gate.md` flows via `{{include}}` to all skill SKILL.md and dist agent outputs. Inline copies in `AGENTS.md` and `src/agents/rubber-duck/body.md` require manual sync.
- **Reference doc**: `src/shared/references/diff-format-examples.md` with 4 examples (edit, new file, multi-file, cosmetic). Landed in `0d48aa8`.

**Installer extras differentiation** (date: 2026-08-01)

- **Default vs extras split**: installer skills split into default set (11, matching .claude-plugin/plugin.json) + extras set (3: duck-adapt, duck-grill, duck-tape). Extras gated behind --extras (bash) / -Extras (PowerShell), optional by default.
- **status extras reporting**: skills_status reports extras separately as optional (present/missing count). Default skills still gate "installed" status.
- **uninstall orphan prevention**: skills_uninstall removes all 14 skills (default + extras) regardless of extras flag so no orphan skills remain.
- **Typo fix bundled**: .sh skills_uninstall had missing closing quote on SKILLS_SOURCE + double space before scope; fixed in same diff.
- **Parity**: both scripts/rubber-duck.sh and scripts/rubber-duck.ps1 updated.

**README extras documentation** (date: 2026-08-01)

- **CLI tables updated**: --extras (bash) and -Extras (PowerShell) rows added to flag tables in scripts/README.md.
- **Skills Sets section**: new subsection under Installation Behavior documents default 11 (plugin.json) vs extras 3, optional-by-default install, uninstall orphan prevention, status extras reporting.
- **Approval classification**: README update treated as semantic per ADR edge case (code snippets users copy-paste); full approval gate applied.

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

- **Build system include directives**: `{{include: skill-snippets/...}}` and `{{include: policy-snippets/...}}` resolved at assembly time. `src/` is source with directives, `skills/` is built mirror.
- **GUARDRAILS.md generation**: `references/GUARDRAILS.md` generated by build system from snippet resolution, not in `src/`.
- **opencode runtime shape**: `client.session.messages()` returns `{ data: [{ info, parts }] }`. Field is `sessionID` (capital ID). `info.time.created` is epoch ms.
- **PowerShell UTF-8 encoding**: `Get-Content`/`Set-Content` need `-Encoding UTF8` to avoid mojibake.
- **Marker format**: `<timestamp> | cwd: <path> | latest-state: <file> | transcript: <path>`. `transcript` field added in Angle B; absent in older markers.
- **State file suffixes**: `-auto` (Angle A), `-recovered` (Angle B), no suffix (manual). Three-tier rotation.
- **extract-raw outputs**: user prompts, tool calls, last 10 assistant messages, potential decisions (pattern-filtered, deduped), failed tool results, session metadata.
- **Build commands**: `make build` (skills + agents), `make check` (guardrails + skills + agents). CI: `.github/workflows/check-source-generated-artifacts.yml`.
- **Test suite shape**: golden-file tests via bash + node, no framework dependency. Fixtures in `tests/fixtures/`, expected output in `tests/expected/`. 16 assertions covering extract-state.sh, extract-raw.sh, opencode.plugin.js.
- **Rotation exclusion**: just-written state file excluded from eviction candidates so fresh checkpoint survives. Three-tier precedence (auto > recovered > manual) unchanged.
- **Inline policy copies**: copies of policy snippets pasted directly into `AGENTS.md` and agent `body.md` (not via `{{include}}`). Manual sync required when snippet source changes; build system does not propagate.
- **Diff format selection rule**: file existence determines format — unified diff for edits to existing files, full content in fenced block for new files. Deterministic, no model interpretation.
- **plugin.json default skills**: .claude-plugin/plugin.json declares 11 skills (quack, duck-debt, duck-debug, duck-design, duck-patch, duck-refactor, duck-review, duck-risk, duck-simplify, duck-teach, duck-triage). duck-adapt, duck-grill, duck-tape NOT listed.
- **Installer extras set**: duck-adapt, duck-grill, duck-tape. Installed only with --extras (bash) / -Extras (PowerShell) flag.
- **Uninstall orphan prevention**: uninstall removes all 14 skills (default + extras) regardless of extras flag so no orphans remain.
- **README Skills Sets section**: scripts/README.md subsection under Installation Behavior listing default 11 skills (plugin.json) and 3 extras with install/uninstall/status behavior.
- **--dry-run bash-only**: rubber-duck.sh supports --dry-run; rubber-duck.ps1 has no -DryRun param. Asymmetry pre-existing.

## Deferred-Debt

## Open-Questions
- Update scripts/README.md CLI reference tables with --extras/-Extras flag? (date: 2026-08-01) [resolved: yes, see README Skills Sets section + CLI table rows]
- Commit installer extras split changes? (date: 2026-08-01)
- Hash out larger holistic README overhaul plan? (date: 2026-08-01)

## Session-Log

### 2026-08-01 05:35 — duck-tape Angle A/B implementation + doc drift cleanup
- Status: merge session state into CONTEXT.md
- `7236ad3` Angle A auto-checkpoint (extract-state.sh/.ps1/opencode.plugin.js)
- `4fbe97f` Angle B LLM-assisted recovery (extract-raw.sh/.ps1, `-recovered.state.md`, marker `transcript:` field)
- `db039dd` follow-ups (dedup bug in extract-state.sh + opencode.plugin.js, Potential Decisions section, Copilot paths, perf verified 68ms/112ms on 1MB)
- `f575458` doc drift fix (7 items across SKILL.md + README.md: Resume read-only claim, Init extract-raw confirmation, raw material section list, three-tier rotation)
- `91d1300` stale rotation text fix in Philosophy Guardrails delta
- `6e24260` fixed STATE_SCHEMA.md rotation text (three-tier eviction), cleaned docs/tmp-plan/
- Synced installed copy `~/.agents/skills/duck-tape/` from built `skills/duck-tape/` (now has hooks/, HOOKS_GUIDE.md, Resume/Init/Harness, three-tier rotation)
- Dropped auto-compact opt-in per user decision
- Validated Angle B recovery end-to-end via `/duck-tape resume`

### 2026-08-01 18:20 — duck-tape hook review fixes, test suite, rotation fix
- Status: review findings fixed, test suite landed, rotation design issue resolved
- `a0972dc` Fix 3 PowerShell bugs (dedup, null guard, stale $all) + JS Date nit
- `25f5c46` Behavioral test suite: 16 assertions across bash + JS runners, CI job added
- `30e3348` Approval gate step 2: "as formatted diff" propagation
- `bce5175` Exclude just-written state file from rotation eviction

### 2026-08-01 19:27 — approval gate diff format spec
- Status: diff format spec landed and propagated to all consumers
- `0d48aa8` Specify diff format for approval gate step 2 (13 files, +135/-10)
- Snippet `src/shared/policy-snippets/mutating-action-gate.md` updated with 3-line spec under step 2
- Reference doc `src/shared/references/diff-format-examples.md` created with 4 examples
- Inline copies in `AGENTS.md` and `src/agents/rubber-duck/body.md` synced manually (not `{{include}}`)

### 2026-08-01 15:57 — installer extras differentiation
- Status: .sh + .ps1 parity applied and verified
- Split REQUIRED_SKILLS into DEFAULT_SKILLS (11) + EXTRAS_SKILLS (3) in both installers
- Added --extras (bash) / -Extras (PowerShell) flag for optional extras install
- skills_status reports extras separately as optional (present/missing count)
- skills_uninstall removes all 14 skills regardless of flag (orphan prevention)
- Fixed .sh skills_uninstall typo (missing quote + double space)
- Verified: bash dry-run (11 default, 14 with --extras), bash -n, pwsh parse check
- Rotated out session state: 2026-08-01-04:05-auto

### 2026-08-01 16:33 — README extras documentation
- Status: README parity applied for extras flag
- Added --extras (bash) and -Extras (PowerShell) rows to CLI flag tables
- Added Skills Sets section: default 11 (plugin.json) + extras 3, optional by default, uninstall orphans, status reporting
- Resolved Open-Question: README CLI reference update
- Rotated out session state: 2026-08-01-0509-auto

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

### Re-derivation 2026-08-01-1820
1. git log --oneline -10 — shows a0972dc, 25f5c46, 30e3348, bce5175
2. git show a0972dc — review finding fixes (extract-state.ps1 + opencode.plugin.js)
3. git show 25f5c46 — behavioral test suite (tests/run.sh, tests/run.js, fixtures, golden files)
4. git show 30e3348 — approval gate "as formatted diff" propagation
5. git show bce5175 — rotation eviction excludes just-written file
6. bash tests/run.sh && node tests/run.js — verify all 16 assertions pass
7. make build-skills && make check-skills — verify build parity

### Re-derivation 2026-08-01-1927
1. git log --oneline -5 — shows 0d48aa8 at top
2. git show 0d48aa8 — diff format spec across 13 files (snippet + reference doc + inline copies + dist propagation)
3. cat src/shared/policy-snippets/mutating-action-gate.md — source snippet with 3-line spec under step 2
4. cat src/shared/references/diff-format-examples.md — 4 examples (edit, new file, multi-file, cosmetic)
5. make build && make check — verify propagation and clean state
6. bash tests/run.sh && node tests/run.js — 16 assertions pass

### Re-derivation 2026-08-01-1557
1. cat .claude-plugin/plugin.json — confirm 11 default skills (no adapt/grill/tape)
2. git diff scripts/rubber-duck.sh — see DEFAULT_SKILLS/EXTRAS_SKILLS split, --extras flag, refactored skills_* functions
3. git diff scripts/rubber-duck.ps1 — see $DefaultSkills/$ExtrasSkills split, -Extras switch, refactored Skills-* functions
4. bash scripts/rubber-duck.sh install --opencode --dry-run 2>&1 | grep skill — confirm default 11 skills in add command
5. bash scripts/rubber-duck.sh install --opencode --extras --dry-run 2>&1 | grep skill — confirm 14 skills in add command
6. bash -n scripts/rubber-duck.sh — bash syntax check
7. pwsh -NoProfile -Command '$null = [System.Management.Automation.PSParser]::Tokenize((Get-Content -Raw scripts/rubber-duck.ps1), [ref]$null); "parse ok"' — PowerShell parse check

### Re-derivation 2026-08-01-1633
1. git diff scripts/README.md — see --extras row, -Extras row, Skills Sets section
2. rtk grep -n "extras\|Extras" scripts/README.md — confirm 4 hits (bash table, powershell table, Skills Sets x2)
3. cat .claude-plugin/plugin.json — confirm 11 default skills match README Skills Sets section
4. git diff scripts/rubber-duck.sh scripts/rubber-duck.ps1 — confirm installer changes that README documents