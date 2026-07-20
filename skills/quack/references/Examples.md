# Quack UX Micro-Spec

<!-- 
asset-type: reference
loading: conditional (on request for examples or disambiguation calibration)
format: usage examples and expected output
last-updated: 2026-07-20
-->

Goal: make `quack` feel like intent routing, not command syntax.

## Interaction Contract

1. Bare `quack`
- show compact quick-help only
- no clarifying question unless user adds task text

2. Resolvable intent
- emit one-line confirmation
  - `Routing: <skill>.`
  - include `via <subagent>` only when user explicitly overrides subagent
- execute immediately (inline or delegated per policy)

3. Unresolvable intent
- ask one targeted disambiguation question
- use compact prompt form: `Need one detail: <question>`
- no route menu

4. Subagent override
- accept `use|with|via <subagent>`
- if valid, override default routing
- if invalid, ask one correction question

## Response Patterns

Success (alias):
- `Routing: duck-review.`

Success (explicit skill):
- `Routing: duck-review.`

Success (override):
- `Routing: duck-review via general.`

Miss:
- `Need one detail: did you mean review, risk, or trace?`

Invalid override:
- `Need one detail: unknown subagent "<x>". Use duckling or general?`

## Route Priority Hints

- diff / PR / changed files → bias `duck-review`
- stack trace / call path / “where used” → bias `duck-debug` (trace mode)
- rollout / migration / compatibility / rollback → bias `duck-risk`
- “overengineered” / “too complex” → bias `duck-simplify`
- “duplicate” / “drift” → bias `duck-simplify`
- “fix/edit/patch” → bias `duck-patch`

## UX Guardrails

- don’t restate policy unless needed
- don’t explain routing internals unless asked
- don’t ask more than one question on alias miss
- don’t block execution after successful route resolution
