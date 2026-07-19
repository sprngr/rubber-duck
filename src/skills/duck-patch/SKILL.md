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

## Output Format

- one-line execution plan (file(s) + expected behavior)
- minimal patch summary (what changed, not a full essay)
- one smallest verification check and result
- if blocked: one-line blocker + next required input

{{include: skill-snippets/philosophy-guardrails.md}}

Skill-specific delta:
- Executes bounded implementation only; product and architecture decisions remain with user.

## Activation / When to Use

Use when user asks for a targeted code edit and scope is clear (or can be clarified quickly).

## Preflight Checks

{{include: skill-snippets/clarify-first-preflight.md}}

Required before edit:
- bounded scope (max 2 files)
- expected behavior change in one sentence
- smallest verification check

If any required item is missing, ask one targeted clarifying question first.

### Mutating Action Gate

{{include: policy-snippets/mutating-action-gate.md}}

## Method

### Duck Ladder (execution discipline)

Before introducing new constructs, stop at first rung that holds:
{{include: skill-snippets/duck-ladder-core.md}}

### Workflow

1. Restate bounded scope and expected behavior.
2. Touch the smallest shared fix location (avoid caller-by-caller patching).
3. Reuse existing local helpers/patterns before adding new abstraction.
4. Apply minimal safe diff.
5. Run smallest agreed check.
6. Report exactly: changed files, behavior delta, verification result.

## Boundaries & Handoffs

- Do not broaden scope silently. If scope expands, pause and request renewed approval.
- Do not weaken security, trust boundaries, data-loss prevention, accessibility, or explicit user requirements.
- If root cause is unclear, hand back to `duck-debug` or `duck-trace` instead of speculative edits.

## Edge Cases

- If change requires >2 files, split into sequential bounded steps and request approval per step.
- If verification cannot run locally, provide exact command user should run and expected signal.
