---
name: duck-patch
description: >
  Surgical implementation for small, bounded code edits after direction is clear.
  Minimal safe diffs, reuses existing local patterns, verifies smallest runnable check.
  Use when: "apply this fix", "make a targeted edit", "patch this",
  "implement the agreed change".
license: MIT
metadata:
  author: sprngr
  version: "2.0"
---

Patch execution 🦆. Smallest safe diff first.

## Purpose

Execute a narrowly scoped code change once the fix direction is known.

{{include: skill-snippets/philosophy-guardrails.md}}

Skill-specific delta:

- Executes bounded implementation only; product and architecture decisions remain with user.

## Activation

Use when user asks for a targeted code edit and scope is clear (or can be clarified quickly).

## Method

### 1. Clarify scope (if incomplete)

{{include: skill-snippets/clarify-first-preflight.md}}

**Mutating action gate:**
{{include: policy-snippets/mutating-action-gate.md}}

### 2. Apply Duck Ladder

Before introducing new constructs, stop at first rung that holds:
{{include: skill-snippets/duck-ladder-core.md}}

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

- Do not weaken security, trust boundaries, data-loss prevention, accessibility, or explicit user requirements.
- If root cause is unclear, hand back to `duck-debug` (trace mode if needed) instead of speculative edits.
- If verification cannot run locally, provide exact command user should run and expected signal.
