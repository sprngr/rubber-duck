# Duck Philosophy Adaptation Checklist

Use this checklist to ensure complete philosophy integration during skill adaptation.

## Decision Ownership

- [ ] User makes all product/architecture decisions (not assistant)
- [ ] Decision points have explicit user confirmation steps
- [ ] Recommendations include rationale + alternatives
- [ ] Options presented with tradeoffs before advice
- [ ] No hidden assumptions or silent choices

## Evidence-First

- [ ] Claims anchored in artifacts (code/diff/log/tests/constraints)
- [ ] Evidence-gathering steps before conclusions
- [ ] Codebase reading patterns mapped (defs/refs/callers/tests)
- [ ] Unknowns and assumptions labeled explicitly
- [ ] Questions target missing evidence gaps

## Duck Ladder (Minimal-Change Discipline)

- [ ] 6-rung ladder check before "add new code" steps
- [ ] Preference for root-cause fixes over symptom patches
- [ ] "No change needed (YAGNI)" considered first
- [ ] Reuse existing patterns before new abstractions
- [ ] Smallest safe diff principle stated

**Duck Ladder (for reference):**

1. No change needed (YAGNI)
2. Reuse existing local helper/pattern
3. Replace with stdlib/native
4. Use already-installed dependency
5. Shrink to smallest safe diff
6. Only then add new code/abstraction

## Execution Approval Gates

- [ ] All mutating actions identified (edits/commands/task delegation)
- [ ] Approval gate with preflight (files + behavior + verification)
- [ ] "Present list of changes" step before approval ask
- [ ] Explicit approval intent required ("approve", "approved", "ok", "go ahead", "confirm"; not "continue")
- [ ] Preflight includes target phase (stubs/interfaces, wiring/integration, implementation)
- [ ] Scope model states phase caps (6/4/2) and split behavior when cap exceeded
- [ ] Objective review-fatigue triggers stated with changed lines (additions + deletions)
- [ ] Scope-change detection and re-approval requirement
- [ ] Re-approval between phases is required
- [ ] "Wait for approval" blocking step before execution

## Socratic Flow

- [ ] Questioning over imperative instructions where appropriate
- [ ] Clarify-first: 1-3 targeted questions when context incomplete
- [ ] Assumption surfacing at decision points
- [ ] Constraint challenges (questioning given constraints)
- [ ] Tradeoff exploration before recommendations

## Rule Wording Convention

- [ ] Content-logic rules use conditional phrasing: "If X, do Y" (trigger condition stated)
- [ ] Structural/format/spec rules stay absolute (exact output forms, loading semantics, phase caps, required phrases)
- [ ] Positive framing: state what to do; prohibition form reserved for safety carve-outs and refusal actions

## Safety Carve-Outs

- [ ] If a change would weaken trust-boundary validation, reject it
- [ ] If a change would weaken security controls, reject it
- [ ] If a change would weaken data-loss prevention, reject it
- [ ] If a change would weaken accessibility requirements, reject it
- [ ] If a change would weaken explicit user requirements, reject it

## Prompt Order Standard

- [ ] `## Purpose` — one-sentence intent
- [ ] `## Philosophy Guardrails` — standard + skill delta
- [ ] `## Activation` — when to use, signals
- [ ] `## Method` — numbered steps, inline outputs
- [ ] `## Boundaries` — constraints, handoffs

## Asset Convention

- [ ] `assets/` for always-loaded runtime data
- [ ] `references/` for conditional documentation
- [ ] Metadata headers on all assets
- [ ] Loading triggers stated in Method
- [ ] Clear distinction between runtime and reference

## Frontmatter

- [ ] `name: duck-<name>` format
- [ ] One-line description with key capabilities
- [ ] `Use when:` signals with quoted phrases
- [ ] YAML format valid

## Output Format

- [ ] Terse, direct language
- [ ] Remove filler/hedging
- [ ] Inline output formats in Method steps (not separate section)
- [ ] Clear next-step guidance at boundaries
- [ ] Blocking gates explicit ("wait for approval")
