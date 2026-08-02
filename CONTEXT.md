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
- **Build commands**: `make build` (skills + agents), `make check` (guardrails + skills + agents). CI: `.github/workflows/check-source-generated-artifacts.yml`.
- **Test suite shape**: golden-file tests via bash + node, no framework dependency. Fixtures in `tests/fixtures/`, expected output in `tests/expected/`. 16 assertions covering extract-state.sh, extract-raw.sh, opencode.plugin.js.
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
- Commit installer extras split changes? (date: 2026-08-01) [resolved: yes, commit 461d8a4]
- Hash out larger holistic README overhaul plan? (date: 2026-08-01) [resolved: yes, landed in 0490b1b + 89be11f + 106d13b]

## Notes

### 2026-08-02 14:30
**Current system shape (source-first)**

- Agent source: `src/agents/<name>/` (`meta.json` + `body.md`)
- Skill source: `src/skills/*/SKILL.md`
  - 14 active skills: duck-adapt, duck-debug, duck-debt, duck-design, duck-grill, duck-patch, duck-refactor, duck-review, duck-risk, duck-simplify, duck-tape, duck-teach, duck-triage, quack
  - Routing model: inline-default (4 skills: debug, debt, design, teach), delegated-default (6 skills: patch, refactor, review, risk, simplify, triage), governor-invoked (2 skills: adapt, grill), router-only (1 skill: quack)
  - Asset structure: `assets/` (runtime, always loaded) vs `references/` (conditional docs)
- Canonical shared guardrails source: `src/shared/references/GUARDRAILS.md`
- Shared snippets: `src/shared/policy-snippets/` (atomic policy fragments) + `src/shared/skill-snippets/` (atomic skill fragments)
- Generated skill artifacts: `skills/*/` (for `npx skills`)
- Generated harness artifacts: `dist/{claude,opencode,copilot}/`
- Global policy: `AGENTS.md`
- Architecture docs: `docs/architecture/`
- Validation suite: `docs/validation/` (test-prompts.json + run-validation-tests.sh)