# Duck-Adapt Examples

Real-world examples of skill adaptation with philosophy transformation details.

---

## Example 1: External Imperative Skill -> Duck-Adapted

### Before (External Skill: "Auto-Fix")

```markdown
# Auto-Fix Skill

Automatically fix common code issues.

## Usage
When you see broken code, run auto-fix to repair it.

## Steps
1. Scan code for issues
2. Apply standard fixes
3. Run tests
4. Commit if tests pass
```

**Problems:**
- No user decision ownership (autopilot execution)
- No evidence gathering before fixes
- No approval gate before mutating actions
- No tradeoff discussion
- Silent implementation without rationale

### After (Duck-Adapted: "duck-fix")

```markdown
---
name: duck-fix
description: >
  Identify fixable code issues and propose minimal safe repairs with user approval.
  Evidence-first issue detection, Duck Ladder discipline, execution approval required.
  Use when: "what can be fixed", "suggest repairs", "fix common issues".
---

## Purpose

Identify mechanical code issues and propose minimal safe repairs after user confirms direction.

{{include: skill-snippets/philosophy-guardrails.md}}

Skill-specific delta:
- User decides which issues to fix and approves execution
- Proposes fixes with rationale; does not auto-apply

## Activation

Use when user asks to identify fixable issues or requests repair suggestions.

## Method

### 1. Evidence gathering

Ask clarifying questions (up to 3):
- Scope: which files or directories to analyze?
- Issue types: specific categories (security, performance, style) or all?
- Severity filter: critical only, or include low-priority issues?

Scan specified scope and identify issues with:
- Location (file:line)
- Issue type (security, bug, style, etc.)
- Evidence (why this is an issue)
- Severity (critical, high, medium, low)

### 2. Present findings

Group issues by severity and type:

**Critical (require immediate attention):**
- [C1] `file.js:42` — SQL injection risk — untrusted input in query
- [C2] `auth.js:15` — Auth bypass — missing permission check

**High:**
- [H1] `utils.js:88` — Null pointer risk — missing null check before access

Output format:
- Prefix + location + issue type + evidence
- Prioritized list (critical -> low)
- Count per severity

### 3. Proposal with Duck Ladder

For each issue user wants to fix, apply Duck Ladder:

1. **No change needed?** — Sometimes "issue" is intentional
2. **Reuse existing pattern?** — Project already has helper for this
3. **Stdlib solution?** — Native API exists
4. **Existing dependency?** — Already-installed library covers this
5. **Smallest safe diff?** — Minimal patch preserving correctness
6. **Add new code?** — Only if no other rung holds

Present fix proposal:
- Issue: [description]
- Duck Ladder assessment: [which rung applies]
- Proposed fix: [what to change]
- Rationale: [why this fix is minimal and safe]
- Alternative: [if applicable]

Ask: "Which issues should I fix? Reply with issue IDs (e.g., C1, H1)."

### 4. Execution approval

For selected issues:

**Preflight:**
- Target phase:
  - Phase 1: stubs/interfaces
  - Phase 2: wiring/integration
  - Phase 3: concrete implementation
- Target files: [bounded list for selected phase]
- Expected behavior change: [what will work differently]
- Verification check: [smallest test/command to confirm fix]

**Approval ask:** `Reply with "approve" to execute this scope.`

**Wait for approval.** Do not proceed until user replies with "approve".

### 5. Apply fixes

1. Apply minimal safe diff per issue
2. Reuse existing local patterns
3. Preserve existing style/conventions
4. Run agreed verification check
5. Report: files changed + behavior delta + verification result

### 6. Report

Output:
- Fixed issues: [ID list with one-line summary each]
- Files changed: [list]
- Verification result: [pass/fail + evidence]
- Remaining issues: [count by severity]

## Boundaries

- Do not auto-fix without approval; always present findings first
- Do not broaden scope beyond approved files/issues
- Do not weaken security, trust boundaries, data protection
- If root cause unclear, hand to `duck-debug` for investigation
- If fix exceeds phase cap or review-fatigue triggers, split and request approval per batch
```

**Transformations applied:**
- ✅ Decision ownership: User selects issues and approves execution
- ✅ Evidence-first: Issue detection with location + evidence + severity
- ✅ Duck Ladder: Applied before proposing fixes
- ✅ Execution approval: Preflight -> present changes -> approval ask -> wait -> execute
- ✅ Socratic flow: Clarifying questions for scope/severity

---

## Example 2: Workflow Description -> Duck-Adapted

### Before (User Request)

"I want a skill that helps me write commit messages. It should look at the diff and generate a good commit message following conventional commits format."

**Initial analysis:**
- Intent: Assist with commit message authoring
- Scope: Non-mutating (suggestion only) or mutating (auto-commit)?
- Evidence source: git diff
- Output: Commit message text

**Clarifying questions:**
1. Should this skill suggest messages for review, or auto-commit?
2. What conventional commit types does your project use? (feat/fix/docs/etc.)
3. Should it analyze commit history for style consistency?

**User answers:**
1. Suggest only, I'll review and edit
2. Standard types: feat, fix, docs, refactor, test, chore
3. Yes, match existing style

### After (Duck-Adapted: "duck-commit")

```markdown
---
name: duck-commit
description: >
  Generate conventional commit messages from diff analysis and commit history patterns.
  Evidence-first diff review, style consistency check, suggestion only (no auto-commit).
  Use when: "suggest commit message", "write commit msg", "commit message help".
---

## Purpose

Analyze staged changes and suggest conventional commit messages matching project style.

{{include: skill-snippets/philosophy-guardrails.md}}

Skill-specific delta:
- Suggests messages; does not auto-commit
- User edits and commits manually

## Activation

Use when user asks for commit message suggestions or help writing conventional commits.

## Method

### 1. Evidence gathering

Check prerequisites:
- Staged changes exist? (`git diff --cached`)
- Commit history accessible? (`git log`)
- Conventional commit format used? (scan recent commits)

If no staged changes, ask: "Stage changes first with `git add`, or analyze working directory instead?"

### 2. Analyze changes

Parse diff for:
- Files changed (by category: src, test, docs, config)
- Change type per file (added, modified, deleted)
- Scope hints (module names, component names)
- Breaking changes (API signature changes, removed exports)

Check recent commit history (last 20) for:
- Common commit types used (feat, fix, etc.)
- Scope patterns (e.g., `feat(api):`, `fix(auth):`)
- Style preferences (emoji usage, sentence case vs lowercase, period at end)

### 3. Generate suggestions

Produce 3 commit message candidates:

**Option A (concise):**
```
<type>(<scope>): <summary>

<body if needed>
```

**Option B (detailed):**
```
<type>(<scope>): <summary>

- <change detail 1>
- <change detail 2>

<footer if breaking>
```

**Option C (alternative framing):**
```
<type>(<alt-scope>): <alt-summary>
```

Each option includes:
- Conventional commit format adherence
- Scope derived from files changed
- Summary reflecting primary change intent
- Breaking change footer if detected

### 4. Present with rationale

Output format:

```markdown
## Commit Message Suggestions

**Files changed:** [count] ([categories])
**Change type detected:** [feat/fix/refactor/etc.]
**Scope hint:** [module/component]
**Breaking changes:** [Yes/No]

---

**Option A (Recommended):**
```
<commit message>
```
Rationale: [why this framing matches diff + project style]

**Option B:**
```
<commit message>
```
Rationale: [alternative emphasis]

**Option C:**
```
<commit message>
```
Rationale: [different scope/framing]

---

**Next steps:**
1. Copy preferred option
2. Edit as needed
3. Commit: `git commit -m "..."`
```

### 5. Refinement (optional)

If user requests adjustments:
- Ask: "What aspect to adjust? (type/scope/summary/body)"
- Regenerate with user constraint
- Present revised options

## Boundaries

- Suggests only; does not run `git commit`
- Does not modify staged changes
- Does not enforce style (suggests based on history patterns)
- If diff is empty, prompt to stage changes first
- If commit history unavailable, use standard conventional commit format without project-specific style

**Handoffs:**
- If diff is unclear or changes lack focus -> `duck-review` to assess change scope
- If breaking changes detected -> `duck-risk` for compatibility review
```

**Transformations applied:**
- ✅ Decision ownership: User selects and edits message, commits manually
- ✅ Evidence-first: Analyzes diff + commit history before suggestions
- ✅ Socratic flow: Clarifying questions for prerequisites
- ✅ No execution approval needed (non-mutating suggestion only)
- ✅ Rationale provided for each option

---

## Example 3: Audit Existing Skill

### Input

"Audit duck-patch for philosophy compliance."

### Output

```markdown
## 🦆 Skill Audit: duck-patch

### Compliance Check
- ✅ Philosophy guardrails present (include directive used)
- ✅ Prompt order standard followed (Purpose -> Guardrails -> Activation -> Method -> Boundaries)
- ✅ Execution approval gates on mutating actions (step 1 preflight + approval)
- ✅ Asset convention compliance (no assets needed for this skill)
- ✅ Duck Ladder discipline included (step 2 explicit)

### Findings

**High priority:**
- None

**Medium priority:**
- [M1] Method step 1 could clarify "one targeted clarifying question" -> "up to 3 targeted questions" for consistency with other skills
  - Fix: Update "ask one targeted clarifying question" -> "ask 1-3 targeted clarifying questions"

**Low priority:**
- [L1] Boundaries section could add explicit handoff to `duck-refactor` when phase caps or review-fatigue triggers are exceeded
  - Fix: Add "If scope exceeds current phase bounds, hand to `duck-refactor` instead"

### Overlap Analysis
- Semantic overlap with: `duck-refactor` (40% — both implement code changes, but different scope limits)
- Composition opportunities: `duck-debug` -> `duck-patch` (trace + root-cause -> bounded fix)
- Redundancy risk: None (distinct scope and file limits)

### Recommendations
1. [M1] Update clarifying question count for consistency (1 -> 1-3)
2. [L1] Add explicit handoff to duck-refactor in Boundaries

**Overall assessment:** Strong compliance. Minor wording improvements suggested.
```

---

## Example 4: Overlap Detection (High Overlap)

### Input

"I want to add a skill that traces function dependencies and shows where they're used."

### Output

```markdown
## 🦆 Overlap Analysis: Function Dependency Tracer

### Existing Coverage

**Primary match:** `duck-debug` (trace mode) — 95% overlap

**Intent overlap:**
- Both trace function usage across codebase
- Both map definitions, references, callers, tests
- Both provide evidence map for investigation

**Workflow overlap:**
- Proposed: "find function -> show dependencies -> list callers"
- duck-debug trace: "entry point -> defs/refs/callers/tests -> evidence map"

**Unique value of proposed skill:**
- None identified; duck-debug trace mode already covers this workflow

### Gap Analysis

**What duck-debug trace provides:**
- Definition location
- Reference sites
- Caller mapping
- Test coverage check
- Evidence-structured output

**What proposed skill would add:**
- (No distinct value found)

### Composition Alternative

Use existing workflow:
```
quack duck-debug
-> select "trace mode"
-> specify function name
-> receive dependency map
```

### Recommendation

**Reject — Use duck-debug trace mode instead**

**Rationale:** 95% semantic overlap with duck-debug trace mode. Proposed skill adds no distinct value and would create routing confusion. Existing skill already provides function dependency tracing with evidence-structured output.

**Suggested workflow:** `quack duck-debug` + "trace mode" achieves same outcome.
```

---

## Example 5: Overlap Detection (Low Overlap - Viable New Skill)

### Input

"I want a skill that helps plan database migrations with rollback safety."

### Output

```markdown
## 🦆 Overlap Analysis: Database Migration Planner

### Existing Coverage

**Primary match:** `duck-risk` — 30% overlap
- Shared: rollback safety analysis, compatibility review
- Unique to proposed: migration-specific patterns, schema evolution, data backfill

**Secondary match:** `duck-design` — 25% overlap
- Shared: option evaluation, tradeoff analysis
- Unique to proposed: migration sequencing, backward compat windows

### Gap Analysis

**What existing skills provide:**
- `duck-risk`: General failure mode analysis, rollback assessment
- `duck-design`: Architecture option comparison

**What proposed skill would add:**
- Migration-specific patterns (additive-only, expand-contract, dual-write)
- Schema evolution planning (phase 1 -> phase 2 -> cleanup)
- Data backfill strategies
- Rollback automation (how to reverse migration)
- Breaking change windows
- Multi-tenant migration coordination

**Unique value:** Domain-specific migration expertise not covered by general-purpose skills.

### Composition Alternative

Partial coverage via:
```
quack duck-design
-> evaluate migration approaches
-> hand to duck-risk for rollback review
```

But lacks migration-specific patterns and sequencing logic.

### Recommendation

**Add new skill: `duck-migrate`**

**Rationale:** Low overlap (<40%) with existing skills. Proposed skill addresses migration-specific domain knowledge (schema evolution, backfill, phasing) not covered by general design/risk skills. High value for teams managing databases.

**Suggested scope:**
- Migration strategy (additive vs breaking)
- Phased rollout plan
- Rollback automation
- Backward compat windows
- Data backfill patterns

Would complement `duck-design` (for high-level approach) and `duck-risk` (for failure modes), but provide migration-specific depth.
```

---

## Key Patterns from Examples

### Imperative -> Socratic
- Replace "do X" with "ask about X context, present options, get approval"
- Insert clarifying questions before execution
- Make assumptions explicit

### Autopilot -> Approval-Gated
- Identify mutating actions (edits, commands, commits)
- Add preflight (files + behavior + verification)
- Add blocking approval gate
- Add scope-change detection

### Black-Box -> Evidence-First
- Add evidence-gathering steps before conclusions
- Cite locations, definitions, tests, constraints
- Label unknowns explicitly

### Complex -> Duck Ladder
- Before "add new code", check 6 rungs
- Prefer reuse over invention
- Prefer root-cause fixes over symptom patches

### Ambiguous -> Structured
- Apply prompt order standard
- Inline outputs in Method steps
- Clear boundaries and handoffs
