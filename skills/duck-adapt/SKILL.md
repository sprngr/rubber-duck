---
name: duck-adapt
description: >
  Meta-skill that adapts external skills to rubber-duck philosophy: Socratic method,
  evidence-first discipline, Duck Ladder, execution approval gates, and prompt order standard.
  Also audits existing skills for philosophy compliance and detects overlaps.
  Use when: "adapt this skill", "make this duck-compatible", "audit skill",
  "should we add this skill".
license: MIT
metadata:
  author: sprngr
  version: v2.1.0
  RUBBER_DUCK_VERSION: v2.1.0
---

Skill adapter 🦆. External skill -> duck philosophy.

## Purpose

Transform external skills or workflows into rubber-duck-grounded versions that preserve intent while adding:

- Socratic questioning flow
- Evidence-first discipline
- Duck Ladder minimal-change thinking
- Execution approval gates
- Prompt order standard compliance

Also validates existing duck-* skills and detects unnecessary duplication.

## Philosophy Guardrails (skill-local)

Inherit shared guardrails from `references/GUARDRAILS.md`.
- ask 1-3 targeted clarifying questions when context is incomplete
- state assumptions explicitly when evidence is missing

Skill-specific delta:

- Meta-skill: operates on skill definitions, not codebase directly
- Output is skill draft, not implementation
- Recommends skill rejection when overlap/duplication detected

## Activation

Use when:

- User provides external skill to adapt
- User describes workflow/process to convert into skill
- User asks to audit existing skill for philosophy compliance
- User asks "should we add this skill" or "does this overlap"

## Method

### 1. Intake and classification

Ask clarifying questions (up to 3) to establish:

**For external skill adaptation:**

- Input format: full skill markdown, workflow doc, or concept description?
- Intent: what problem does this skill solve?
- Scope: mutating actions (edits/commands) or non-mutating (analysis/advice)?
- Target audience: what context does user expect?

**For skill audit:**

- Which skill to audit? (name or path)
- Audit depth: quick compliance check or full overlap analysis?

**For overlap detection:**

- Skill concept summary
- Expected workflow steps
- Comparison against existing skills requested?

### 2. Evidence gathering

**For external skill:**

- Parse input: extract steps, constraints, outputs, examples
- Identify decision points (where user choice matters)
- Identify mutating actions (require approval gates)
- Identify evidence gaps (where code/diff/log reading needed)

**For skill audit:**

- Read skill source from `src/skills/<name>/SKILL.md`
- Check against philosophy guardrails
- Check against prompt order standard (04-prompt-order-standard.md)
- Check for execution approval gates on mutating actions
- Check asset convention compliance (07-skill-asset-convention.md)

**For overlap detection:**

- Load existing skill summaries from `src/skills/*/SKILL.md` frontmatter
- Compare intent, scope, workflow patterns
- Identify semantic overlap vs complementary composition

### 3. Philosophy mapping

Load philosophy assets:

- `assets/philosophy-core.md` — Complete duck philosophy reference
- `assets/socratic-patterns.md` — 10 transformation patterns (imperative->question, autopilot->approval, etc.)
- `assets/approval-gate-spec.md` — 6-step execution approval specification
- `assets/adaptation-checklist.md` — Comprehensive transformation checklist

Apply rubber-duck philosophy transformations using loaded patterns:

**Decision ownership:**

- Inject clarifying questions at decision points
- Make user choice explicit ("Which option?" not "I'll pick X")
- Surface tradeoffs before recommendations
- Pattern: Imperative -> Question (socratic-patterns.md #1)

**Evidence-first:**

- Add evidence-gathering steps before conclusions
- Map to codebase reading patterns (defs/refs/callers/tests)
- Anchor claims in artifacts
- Pattern: Black-Box -> Evidence-First (socratic-patterns.md #3)

**Duck Ladder:**

- Add minimal-change discipline to implementation steps
- Insert 6-rung ladder check before "add new code" steps
- Prefer root-cause fixes over symptom patches
- Pattern: Complex -> Duck Ladder (socratic-patterns.md #6)

**Execution approval:**

- Identify all mutating actions (edits, commands, task delegation)
- Insert 6-step approval gate (approval-gate-spec.md)
- Add preflight (files + behavior + verification)
- Add scope-change detection
- Pattern: Autopilot -> Approval Gate (socratic-patterns.md #2)

**Socratic flow:**

- Convert imperative steps to questioning steps where appropriate
- Add assumption surfacing
- Add constraint challenge opportunities
- Patterns: Single-Path -> Multi-Option (socratic-patterns.md #4), Tell -> Show Options (#8)

### 4. Structure transformation

Apply prompt order standard:

**Skill sections (in order):**

1. `## Purpose` — one-sentence intent + key transformations
2. `## Philosophy Guardrails` — include standard + skill-specific delta
3. `## Activation` — when to use, user signals
4. `## Method` — numbered steps with inline output formats
5. `## Boundaries` — constraints, handoffs, scope limits

**Asset identification:**

- `assets/` candidates: always-loaded data (checklists, templates, matrices)
- `references/` candidates: conditional docs (examples, patterns, edge cases)

**Frontmatter:**

```yaml
---
name: duck-<name>
description: >
  One-line purpose. Key capabilities. Use when: "signal phrases".
---
```

### 5. Overlap analysis

Load overlap detection asset:

- `assets/overlap-patterns.md` — Intent map for all 12 skills + scoring rules

Check against existing skills using loaded patterns:

**Overlap scoring (from overlap-patterns.md):**

- **High overlap (>70% intent match):** Recommend rejection or merge
- **Medium overlap (40-70%):** Suggest extension of existing skill
- **Low overlap (<40%):** New skill viable if distinct value clear
- **Complementary:** Composition pattern instead of new skill

**Red flags (from overlap-patterns.md):**

- Autopilot execution (no user decision points)
- Silent implementation (no approval gates)
- Black-box advice (no evidence grounding)
- Safety bypass (weakens trust boundaries/security)
- High duplication (>90% overlap)

**Composition patterns (from overlap-patterns.md):**

- debug->patch, review->risk->simplify, design->triage, teach->debug

### 6. Output generation

**For skill adaptation:**

Emit full directory structure:

```
src/skills/duck-<name>/
├── SKILL.md (full skill definition)
├── assets/ (if always-loaded data needed)
│   └── <template/checklist>.md
├── references/ (if conditional docs needed)
│   └── EXAMPLES.md
└── evals/ (skeleton)
    └── evals.json
```

**Output format:**

```markdown
## 🦆 Skill Adaptation: duck-<name>

### Adaptation Overlap Analysis
- **Semantic overlap:** [None | Low | Medium | High] with [existing skills]
- **Recommendation:** [Add as new skill | Extend existing | Reject (use X instead) | Composition pattern]
- **Rationale:** [one-line justification]

### Philosophy Transformations Applied
- ✅ Decision ownership: [what changed]
- ✅ Evidence-first: [what changed]
- ✅ Duck Ladder: [what changed]
- ✅ Execution approval: [what changed]
- ✅ Socratic flow: [what changed]

### Skill Definition
[Full SKILL.md content]

### Assets (if any)
[Asset file contents with metadata headers]

### Next Steps
1. Review adaptation for intent preservation
2. Confirm overlap assessment
3. If approved: run `make build-skills` to generate artifacts
```

**For skill audit:**

```markdown
## 🦆 Skill Audit: <skill-name>

### Compliance Check
- ✅/❌ Philosophy guardrails present
- ✅/❌ Prompt order standard followed
- ✅/❌ Execution approval gates on mutating actions
- ✅/❌ Asset convention compliance
- ✅/❌ Duck Ladder discipline included

### Findings
**High priority:**
- [H1] [issue description + fix suggestion]

**Medium priority:**
- [M1] [issue description + fix suggestion]

**Low priority:**
- [L1] [issue description + fix suggestion]

### Overlap Analysis
- Semantic overlap with: [other skills]
- Composition opportunities: [patterns]
- Redundancy risk: [None | Low | Medium | High]

### Audit Recommendations
[Prioritized list of changes or "No changes needed"]
```

**For overlap detection:**

```markdown
## 🦆 Overlap Analysis: <concept>

### Existing Coverage
- **Primary match:** [skill name] — [overlap %] — [why]
- **Secondary match:** [skill name] — [overlap %] — [why]

### Gap Analysis
- **Unique value:** [what this concept adds that existing skills don't cover]
- **Composition alternative:** [how existing skills could be chained instead]

### Recommendation
[Add new skill | Extend existing | Use composition | Not needed]

**Rationale:** [2-3 sentence justification]
```

## Boundaries

- Do not generate skills that weaken safety carve-outs (trust boundaries, security, data protection, accessibility)
- Do not adapt skills that automate away user decision ownership without explicit approval gates
- If external skill philosophy conflicts irreconcilably with duck principles, recommend rejection with rationale
- Overlap analysis is advisory; user makes final call on skill addition
- Generated skills are drafts; user reviews before committing
- Do not execute `make build-skills` automatically; user runs after approval

**Handoffs:**

- If user approves new skill -> "Run `make build-skills` to generate artifacts"
- If audit reveals issues -> suggest `duck-patch` for small fixes or `duck-refactor` for restructuring
- If overlap is high -> suggest using existing skill with explicit workflow
