# Quack UX Micro-Spec

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
- stack trace / call path / "where used" → bias `duck-debug` (trace mode)
- rollout / migration / compatibility / rollback → bias `duck-risk`
- "overengineered" / "too complex" → bias `duck-simplify`
- "duplicate" / "drift" → bias `duck-simplify`
- "fix/edit/patch" → bias `duck-patch`

## Skill Composition Examples

Multi-skill workflows using natural language chaining:

**Debug → Patch**:
```
User: quack debug this endpoint failure then patch it
Expected: Routes to duck-debug first, then suggests duck-patch after root cause identified
```

**Review → Risk → Simplify** (comprehensive review):
```
User: quack review this refactor for correctness, risk, and complexity
Expected: Routes to duck-review with note to follow up with duck-risk and duck-simplify
```

**Design → Triage**:
```
User: quack design this migration and suggest test scenarios
Expected: Routes to duck-design, then suggests duck-triage for test planning
```

**Teach → Debug**:
```
User: quack explain this auth flow then help debug the token expiry
Expected: Routes to duck-teach first, then duck-debug for investigation
```

**Notes:**
- Composition is user-initiated (not enforced)
- Quack routes to first skill, suggests next steps
- User maintains control of when to proceed to next skill
- Each skill can be invoked independently

## UX Guardrails

- don’t restate policy unless needed
- don’t explain routing internals unless asked
- don’t ask more than one question on alias miss
- don’t block execution after successful route resolution
