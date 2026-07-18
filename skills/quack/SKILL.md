---
name: quack
description: Explicit user-invoked routing workflow for rubber-duck. Presents 1-3 route options, recommends one with a brief reason, and requires user route choice before routing continues. Use when user prefixes with "quack" or asks for explicit route control.
---

# Skill: quack

Explicit route control 🦆. User decides route. Keep terse.

## Purpose

Provide explicit, user-controlled routing for workflow-like requests while preserving all existing safety and approval constraints.

## Output Format

On explicit `quack`, respond in this order:

0. **Heartbeat fast path (bare `quack`)**
   - if input is exactly `quack` (ignoring surrounding whitespace), respond with:
     - `🦆` + brief status line
     - one-line prompt asking what to route next
   - do not emit full route options unless user provides task intent

1. **Route options (1-3 max)**
   - each option includes:
     - `id` (A/B/C)
     - `route` (e.g., `duck-debug`)
     - `best_for` (when to pick it)
     - `tradeoff` (what it deprioritizes)
     - `chain` (expected subagent/skill sequence)

2. **Recommendation (exactly one)**
   - identify recommended option id
   - include one-line reason grounded in user text/artifacts

3. **Explicit choice prompt**
   - ask user to choose option id before continuing

If choice is ambiguous/invalid:
- ask one narrowed follow-up
- remain in route-selection mode

## Philosophy Guardrails (skill-local)

## Philosophy Guardrails (skill-local)

Inherit shared guardrails from `references/GUARDRAILS.md`.

## Activation / When to Use

Use only when the user explicitly invokes `quack`.

Do not auto-activate from inferred intent.

## Preflight Checks

- ask 1-3 targeted clarifying questions when context is incomplete
- state assumptions explicitly when evidence is missing

Required:
- user request containing `quack` invocation
- available route set (debug/review/design/explain/teach/triage)
- active guardrails and mutating-action policy from host agent

Optional:
- artifacts (diff/code/logs/docs)
- constraints (deadline, risk tolerance, desired depth/format)

Ambiguity/confirmation:
- route-level ambiguity only
- user must choose a route before workflow routing continues
- mutating actions still require approval gate after route choice

## Route option format (canonical)

Use this compact shape:

`A | route=duck-debug | best_for=runtime breakage/root-cause tracing | tradeoff=slower than quick scan | chain=duck-debug -> duck-investigator -> duck-triage? -> duck-builder(on explicit patch request)`

`B | route=duck-review | best_for=diff risk scan and concrete review comments | tradeoff=less runtime diagnosis depth | chain=duck-review -> duck-reviewer + duck-adversary + duck-simple (+ duck-dry signal) (+ duck-triage test-gap)`

`C | route=duck-design | best_for=approach/tradeoff decisions | tradeoff=not a runtime bug trace | chain=duck-design -> duck-simple + duck-adversary (+ duck-dry signal)`

## Method

1. verify explicit `quack` invocation
2. if bare `quack`, run heartbeat fast path and stop
3. otherwise provide 1-3 route options with chain hints, recommend one, and require user choice
4. hand off to chosen route flow; if mutating, enforce approval checkpoint before any mutation

## Boundaries & Handoffs

- this skill never auto-routes; it requires explicit invocation and user route choice
- no forced route; user retains route decision ownership
- do not weaken:
  - trust-boundary validation
  - security controls
  - data-loss prevention
  - accessibility requirements
  - explicit user requirements
- preserve core safeguards:
- never weaken trust-boundary validation, security controls, data-loss prevention, accessibility requirements, or explicit user requirements

- no edits/mutating commands/task delegation that changes workspace state without explicit bounded approval

## Failure / fallback behavior

If route confidence is materially low:
- state assumptions in one line
- ask one targeted disambiguation question
- do not proceed until user selects a route

## Edge Cases

- bare `quack` only: respond with heartbeat fast path (`🦆` + brief status + one-line prompt), no full route list
- ambiguous route choice (`A/B/C` unclear): ask one narrowed follow-up and remain in route-selection mode
- confidence insufficient on initial task text: ask one targeted disambiguation question before proposing routes
- mutating path selected: route handoff still requires explicit bounded approval before any mutation

For regression checks, see `evals/evals.json`.

Load `references/Examples.md` when user asks for concrete route output examples or when route-choice wording needs calibration.
