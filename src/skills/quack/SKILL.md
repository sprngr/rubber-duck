---
name: quack
description: Explicit user-invoked routing workflow for rubber-duck. Presents 1-3 route options, recommends one with a brief reason, and requires user route choice before routing continues. Use when user prefixes with "quack" or asks for explicit route control.
---

# Skill: quack

Explicit route control 🦆. User decides route. Keep terse.

## Purpose

Provide explicit, user-controlled routing for workflow-like requests while preserving all existing safety and approval constraints.

{{include: skill-snippets/philosophy-guardrails.md}}

## Activation / When to Use

Use only when the user explicitly invokes `quack`.

Do not auto-activate from inferred intent.

## Input contract

{{include: skill-snippets/clarify-first-preflight.md}}

Required:
- user request containing `quack` invocation
- available route set (debug/review/design/explain/teach/triage)
- active guardrails and mutating-action policy from host agent

Optional:
- artifacts (diff/code/logs/docs)
- constraints (deadline, risk tolerance, desired depth/format)

Accepted ambiguity:
- route-level ambiguity only

Required confirmation points:
1. user must choose a route before workflow routing continues
2. mutating actions still require approval gate after route choice

## Output contract

On explicit `quack`, respond in this order:

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

## Route option format (canonical)

Use this compact shape:

`A | route=duck-debug | best_for=runtime breakage/root-cause tracing | tradeoff=slower than quick scan | chain=duck-debug -> duck-investigator -> duck-triage? -> duck-builder(on explicit patch request)`

`B | route=duck-review | best_for=diff risk scan and concrete review comments | tradeoff=less runtime diagnosis depth | chain=duck-review -> duck-reviewer + duck-adversary + duck-simple (+ duck-dry signal) (+ duck-triage test-gap)`

`C | route=duck-design | best_for=approach/tradeoff decisions | tradeoff=not a runtime bug trace | chain=duck-design -> duck-simple + duck-adversary (+ duck-dry signal)`

## Method

1. verify explicit `quack` invocation
2. derive 1-3 candidate routes from request + artifacts
3. include chain hints for each option
4. recommend one option with one-line rationale
5. require user choice
6. hand off to chosen route flow
7. if chosen path becomes mutating, enforce approval checkpoint before any mutation

## Boundary contract

- no silent auto-routing outside explicit `quack`
- no forced route; user retains route decision ownership
- do not weaken:
  - trust-boundary validation
  - security controls
  - data-loss prevention
  - accessibility requirements
  - explicit user requirements
- preserve core safeguards:
{{include: policy-snippets/safety-carveouts.md}}
- no edits/mutating commands/task delegation that changes workspace state without explicit bounded approval

## Recommendation style

- short and advisory
- no repeated nagging in same thread unless user intent changes
- if non-`quack` request appears workflow-like, host may emit a soft recommendation to use `quack`; user may ignore

## Failure / fallback behavior

If route confidence is materially low:
- state assumptions in one line
- ask one targeted disambiguation question
- do not proceed until user selects a route
