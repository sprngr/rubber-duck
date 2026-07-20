---
name: duck-patch
description: >
  Surgical implementation skill for small, bounded code edits after direction is clear.
  Applies minimal safe diffs, reuses existing local patterns, and verifies the smallest
  runnable check. Use when: "apply this fix", "make a targeted edit", "patch this",
  or "implement the agreed change".
---

Patch execution 🦆. Smallest safe diff first.

## Purpose

Execute a narrowly scoped code change once the fix direction is known.

## Philosophy Guardrails (skill-local)

Inherit shared guardrails from `references/GUARDRAILS.md`.

Skill-specific delta:
- Executes bounded implementation only; product and architecture decisions remain with user.

## Activation

Use when user asks for a targeted code edit and scope is clear (or can be clarified quickly).

## Method

### 1. Clarify scope (if incomplete)

- ask 1-3 targeted clarifying questions when context is incomplete
- state assumptions explicitly when evidence is missing

Required before edit:
- bounded scope (max 2 files)
- expected behavior change in one sentence
- smallest verification check

If any required item is missing, ask one targeted clarifying question first.

**Mutating action gate:**
**Workspace-changing actions** (all require execution approval):
- File edits (code, docs, config, any text file)
- File creation, deletion, or moves
- Commands that modify workspace (git commit, install, build, deploy)
- Task delegation to subagents for implementation/patching

**Rules:**
- No workspace-changing action without explicit user approval on bounded scope
- If requested execution scope exceeds 2 files, split into smaller bounded tasks before executing
- If scope changes after approval, re-open scope confirmation before continuing


### 2. Apply Duck Ladder

Before introducing new constructs, stop at first rung that holds:
1. No change needed (YAGNI)
2. Reuse existing local helper/pattern
3. Replace with stdlib/native
4. Use already-installed dependency
5. Shrink to smallest safe diff
6. Only then add new code/abstraction

### 3. Execute patch

1. Restate bounded scope and expected behavior.
2. Touch the smallest shared fix location (avoid caller-by-caller patching).
3. Reuse existing local helpers/patterns before adding new abstraction.
4. Apply minimal safe diff.
5. Run smallest agreed check.
6. Report exactly: changed files, behavior delta, verification result.

Output:
- one-line execution plan (file(s) + expected behavior)
- minimal patch summary (what changed, not a full essay)
- one smallest verification check and result
- if blocked: one-line blocker + next required input

## Boundaries

- Do not broaden scope silently. If scope expands, pause and request renewed approval.
- Do not weaken security, trust boundaries, data-loss prevention, accessibility, or explicit user requirements.
- If root cause is unclear, hand back to `duck-debug` (trace mode if needed) instead of speculative edits.
- If change requires >2 files, split into sequential bounded steps and request approval per step.
- If verification cannot run locally, provide exact command user should run and expected signal.
