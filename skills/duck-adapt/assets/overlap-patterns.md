# Overlap Detection Patterns

Patterns for detecting semantic overlap between skill concepts and existing duck-* skills.

## Current Skill Intent Map

### duck-debug

**Intent:** Root-cause investigation, evidence mapping
**Modes:** trace (defs/refs/callers/tests), root-cause (Socratic questioning)
**Signals:** "debug this", "why is X broken", "trace failure", "where used"
**Mutating:** No (analysis only)

**Overlap indicators:**

- "find the bug", "trace execution", "map dependencies", "why failing"

### duck-debt

**Intent:** Read-only deferred-work ledger
**Scope:** TODO/FIXME/HACK/XXX comment aggregation
**Signals:** "duck debt", "what did we defer", "audit deferred work"
**Mutating:** No (read-only)

**Overlap indicators:**

- "show TODOs", "list deferred", "technical debt inventory"

### duck-design

**Intent:** Design option evaluation, tradeoff analysis
**Modes:** option comparison, constraint challenge, tradeoff matrix
**Signals:** "choose between approaches", "architecture tradeoffs", "evaluate options"
**Mutating:** No (decision support only)

**Overlap indicators:**

- "which design", "compare approaches", "tradeoffs", "architecture choice"

### duck-grill

**Intent:** Deep interrogation, assumption/risk pressure testing
**Flow:** One-question-at-a-time, batched (up to 3), pressure calibration
**Signals:** "grill me", "grill this plan", "stress-test decision", "challenge assumptions"
**Mutating:** No (questioning only)

**Overlap indicators:**

- "challenge my plan", "what am I missing", "stress test", "assumption review"

### duck-patch

**Intent:** Bounded implementation (phase-gated scope)
**Scope:** Surgical code edits, minimal safe diff
**Signals:** "apply fix", "make targeted edit", "patch this", "implement agreed change"
**Mutating:** Yes (requires execution approval)

**Overlap indicators:**

- "fix this", "edit these files", "apply change", "implement solution"

### duck-refactor

**Intent:** Multi-file restructuring (phase-gated scope)
**Scope:** Extract/rename/move/inline/pattern-convert
**Signals:** "refactor this", "extract function", "rename across codebase", "move code"
**Mutating:** Yes (requires execution approval)

**Overlap indicators:**

- "restructure", "extract", "rename", "move", "inline", "reorganize"

### duck-review

**Intent:** Risk-first code review
**Output:** One-line paste-ready comments (prefix + location + problem + fix)
**Signals:** "review this", "code review", "review diff"
**Mutating:** No (analysis only)

**Overlap indicators:**

- "review my code", "feedback on diff", "what's wrong", "code quality check"

### duck-risk

**Intent:** Adversarial failure mode analysis
**Scope:** Rollback safety, compatibility, trust-boundary misuse
**Signals:** "what could break", "rollback risk", "compat risk", "stress test"
**Mutating:** No (risk assessment only)

**Overlap indicators:**

- "failure modes", "what breaks", "rollback plan", "backward compat", "edge cases"

### duck-simplify

**Intent:** Complexity reduction, duplication review
**Modes:** dry mode (read-only), semantic divergence detection
**Signals:** "simplify this", "overengineered", "reduce complexity", "DRY this", "dedupe"
**Mutating:** Conditional (requires approval if edits suggested)

**Overlap indicators:**

- "too complex", "simpler way", "duplication", "redundant", "divergence"

### duck-teach

**Intent:** Explain/tutorial with depth modes
**Modes:** "explain this" (4-block), "show me" (compact tutorial), "teach me" (full), "walk through" (step-by-step)
**Signals:** "explain this", "teach me", "show me", "walk me through"
**Mutating:** No (educational only)

**Overlap indicators:**

- "what does this do", "how does this work", "explain", "tutorial", "learn"

### duck-triage

**Intent:** Test coverage analysis, bug severity assessment
**Scope:** Missing tests, test quality, test scenarios, edge cases
**Signals:** "test coverage gaps", "what should we test", "triage this bug", "bug severity"
**Mutating:** No (analysis only)

**Overlap indicators:**

- "what to test", "test gaps", "missing tests", "bug priority", "test quality"

### quack

**Intent:** Explicit routing, intent resolution
**Scope:** Keyword-based precedence, alias matching, disambiguation
**Signals:** "quack", explicit route control
**Mutating:** No (routing only)

**Overlap indicators:**

- "route me", "which skill", "how do I", "help with workflow"

## Overlap Scoring Rules

### High Overlap (>70% intent match)

**Recommendation:** Reject or merge into existing skill
**Rationale:** Too much duplication, confuses routing

**Example:** Skill concept "trace function calls" -> duck-debug trace mode already covers this

### Medium Overlap (40-70% intent match)

**Recommendation:** Extend existing skill with new mode/capability
**Rationale:** Core intent shared, but new angle adds value

**Example:** Skill concept "security review" -> extend duck-review with security lens

### Low Overlap (<40% intent match)

**Recommendation:** New skill viable if distinct value clear
**Rationale:** Different enough to justify separate skill

**Example:** Skill concept "performance profiling" -> duck-debug is about correctness, not performance

### Complementary (composition pattern)

**Recommendation:** Use existing skills in sequence instead of new skill
**Rationale:** Workflow is just skill chaining, not new capability

**Example:** "review then simplify" -> `duck-review` -> `duck-simplify` composition

## Composition Patterns (Existing)

- `debug -> patch` — trace + root-cause -> bounded fix
- `review -> risk -> simplify` — code review -> failure modes -> complexity reduction
- `design -> triage` — option evaluation -> test scenario planning
- `teach -> debug` — explain -> investigate when teaching reveals issue

## Red Flags (Always Recommend Rejection)

- **Autopilot execution:** No user decision points, just "do it"
- **Silent implementation:** No approval gates on mutating actions
- **Black-box advice:** No evidence grounding or rationale
- **Safety bypass:** Weakens trust boundaries, security, data protection
- **Duplication:** >90% overlap with existing skill intent

## Edge Cases

### When overlap score is unclear

- Ask user: "Does this skill overlap with `duck-X`?" with comparison
- Suggest trying existing skill first: "Try `quack duck-X` for this workflow. If it doesn't fit, we can adapt."

### When skill is meta (operates on skills/workflows)

- Lower overlap threshold (meta-skills are inherently complementary)
- Example: `duck-adapt` operates on skill definitions, not codebase

### When skill is specialized (narrow domain)

- Evaluate based on frequency of use vs maintenance cost
- High-frequency + narrow domain -> viable
- Low-frequency + narrow domain -> maybe better as external skill

## Output Format for Overlap Analysis

```markdown
## Overlap Analysis

**Primary match:** [skill-name] — [overlap %]
- Intent overlap: [shared intent description]
- Workflow overlap: [shared steps]
- Unique value: [what new skill adds that existing doesn't]

**Secondary match:** [skill-name] — [overlap %]
- [brief comparison]

**Composition alternative:**
- `quack [skill-1]` -> `quack [skill-2]` achieves same outcome

**Recommendation:** [Add new skill | Extend existing | Use composition | Reject]

**Rationale:** [2-3 sentence justification]
```
