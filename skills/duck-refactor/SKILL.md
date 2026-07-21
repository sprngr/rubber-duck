---
name: duck-refactor
description: >
  Multi-file code restructuring with reference tracking. Extract functions/classes,
  rename across codebase, move code between files, inline, convert patterns.
  Use when: "refactor this", "extract this function", "rename X across codebase",
  "move this to another file", "inline this".
---

# Skill: duck-refactor

Structured refactoring 🦆. Multi-file restructuring with reference tracking.

## Purpose

Support code restructuring through bounded refactoring operations with explicit reference tracking and verification.

## Philosophy Guardrails (skill-local)

Inherit shared guardrails from `references/GUARDRAILS.md`.

Skill-specific delta:
- Multi-file refactoring operations require execution approval with full reference tracking.
- Distinguish from single-file patches and complexity reduction.

## Activation

Use when user asks to refactor, extract, rename across files, move code, inline, or convert patterns.

**Trigger phrases:**
- "refactor this"
- "extract this function/class/method"
- "rename X across the codebase"
- "move this to another file"
- "inline this function"
- "convert this callback to promise"

## Method

### 1. Clarify refactoring scope

- ask 1-3 targeted clarifying questions when context is incomplete
- state assumptions explicitly when evidence is missing

Ask one scoping question if any detail unclear:
- What to extract/rename/move/inline?
- Target destination (new file, existing file, new function name)?
- Scope boundaries (this module, whole codebase)?

### 2. Trace references and dependencies

Use read-only evidence gathering (similar to `duck-debug` trace mode):
- Locate all usages of target code
- Map imports/exports
- Identify callers and callees
- Find test files that reference target
- Note external dependencies

Output: "Found N references across M files: [list]"

### 3. Present refactoring plan

Before any edits, present bounded plan:

**Format:**
```
Refactoring plan:
- Operation: [extract function / rename / move / inline / convert]
- Target: [current name/location]
- Destination: [new name/location]
- Files affected: [list, max 5; ask to split if more]

Changes:
1. [file A]: [change description]
2. [file B]: [change description]

Verification: [tests to run, imports to check]
```

If >5 files affected: "This refactoring touches N files. Split into smaller bounded refactorings?"

### 4. Apply Duck Ladder

Before proposing refactoring approach:
1. No change needed (YAGNI)
2. Reuse existing local helper/pattern
3. Replace with stdlib/native
4. Use already-installed dependency
5. Shrink to smallest safe diff
6. Only then add new code/abstraction

Ask: "Does existing code/pattern already solve this? Can we reuse instead of restructure?"

### 5. Require execution approval

Before executing refactoring:
- Target files (bounded; max 5 for refactoring, though still prefer ≤2)
- Expected structural change (what moves where)
- Verification plan (tests, imports, type checking)

Use execution approval flow:
- `Reply with "approve" to execute this refactoring.`
- Wait for explicit approval
- Do NOT proceed with multi-file refactoring without approval

### 6. Execute refactoring

After approval:
1. Make changes in order (definitions before usages, imports before code)
2. Update imports/exports
3. Maintain consistent formatting
4. Preserve comments and documentation

### 7. Verify refactoring

Run verification plan:
- Tests still pass
- No broken imports
- Type checker passes (if applicable)
- Functionality unchanged

Report: "Refactoring complete. Verification: [test results]. [N] files changed."

## Boundaries

**Distinguish from other skills:**

- **vs duck-patch**: `duck-refactor` is multi-file restructuring; `duck-patch` is single-file bug fix
- **vs duck-simplify**: `duck-refactor` is neutral restructuring; `duck-simplify` is complexity reduction with specific goal
- **vs duck-design**: `duck-refactor` is implementation;`duck-design` is decision/tradeoff analysis
- **vs duck-debug**: `duck-refactor` changes code; `duck-debug` only traces/investigates

**What duck-refactor does NOT do:**
- Single-file edits without restructuring → use `duck-patch`
- Complexity reduction as primary goal → use `duck-simplify`
- Architecture decisions → use `duck-design`
- Just moving files without code changes → use `duck-patch`

**Scope limits:**
- Prefer ≤5 files per refactoring (split larger refactorings)
- If refactoring requires design decisions, pause and route to `duck-design` first
- If refactoring reveals complexity issues, note for `duck-simplify` follow-up

- never weaken trust-boundary validation, security controls, data-loss prevention, accessibility requirements, or explicit user requirements

