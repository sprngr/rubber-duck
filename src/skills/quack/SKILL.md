---
name: quack
description: Explicit user-invoked routing for Rubber Duck. Offers 1-3 route options, recommends one, and requires route choice before continuing. Use when user says "quack" or asks for explicit route control.
---

# Skill: quack

Explicit route control 🦆. User chooses route.

## Purpose

Provide explicit user-controlled routing for workflow-like requests while preserving safety and approval constraints.

## Output Format

On explicit `quack`, respond in this order:

0. **Heartbeat fast path (bare `quack`)**
   - If input is exactly `quack` (trim whitespace): output
     - `🦆` + brief status
     - one-line route-intent prompt
   - Do not emit full route options without task intent.

1. **Route options (1-3 max)**
   - Each option includes: `id` (A/B/C), `route`, `best_for`, `tradeoff`, `chain`.

2. **Recommendation (exactly one)**
   - Recommend one option id with one-line reason grounded in prompt/artifacts.

3. **Choice prompt**
   - Ask user to pick option id before continuing.

If choice is ambiguous/invalid: ask one narrowed follow-up and stay in route-selection mode.

{{include: skill-snippets/philosophy-guardrails.md}}

## Activation / When to Use

Use only when user explicitly invokes `quack`; do not auto-activate from inferred intent.

## Preflight Checks

{{include: skill-snippets/clarify-first-preflight.md}}

Required:
- explicit `quack` invocation
- available route set (`debug`/`review`/`design`/`explain`/`teach`/`triage`)
- active host guardrails + mutating-action policy

Optional:
- artifacts (diff/code/logs/docs)
- constraints (deadline, risk tolerance, depth/format)

Ambiguity/confirmation:
- allow route-level ambiguity only
- require user route choice before routing continues; mutating paths still require approval gate.

## Route option format (canonical)

Use this schema per option:

`<ID> | route=<skill> | best_for=<when to pick> | tradeoff=<what it deprioritizes> | chain=<expected subagent/skill sequence>`

## Method

1. Verify explicit `quack` invocation.
2. If bare `quack`, run heartbeat fast path and stop.
3. Otherwise: provide 1-3 route options with chain hints, recommend one, and require user choice.
4. Hand off to chosen route flow; if mutating, enforce approval checkpoint before mutation.

## Boundaries & Handoffs

- Require explicit invocation and user route choice; no forced route.
- Preserve user decision ownership.
- {{include: policy-snippets/safety-carveouts.md}}
- No edits/mutating commands/task delegation that changes workspace state without explicit bounded approval.

## Failure / fallback behavior

If route confidence is low:
- state assumptions in one line
- ask one targeted disambiguation question
- do not proceed until user selects a route

## Edge Cases

- Mutating path selected: route handoff still requires explicit bounded approval before mutation.
- Load `references/Examples.md` when user asks for concrete route output examples or route-choice wording calibration.
