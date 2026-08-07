---
title: Invocation
---

# Invocation

Rubber Duck has two entry paths: **auto-routing** (skills fire on matching intent) and **explicit routing** via `quack`.

## Auto-routing

When you type something skill-shaped ("review this diff", "why is this failing?"), the relevant skill activates automatically. Precedence keywords rank matches when multiple skills apply.

## Explicit routing with `quack`

Bare `quack` shows a heartbeat + quick-help. To route directly:

```
quack review
quack design
quack debug this failure
```

If the alias is ambiguous, quack asks one targeted disambiguation question.

## Curated alias list

The registry ships with more, but these ten cover most needs:

| Alias | Skill |
|---|---|
| `debug` | duck-debug |
| `review` | duck-review |
| `design` | duck-design |
| `explain` | duck-teach |
| `patch` | duck-patch |
| `refactor` | duck-refactor |
| `simplify` | duck-simplify |
| `risk` | duck-risk |
| `triage` | duck-triage |
| `debt` | duck-debt |

Full registry: `src/skills/quack/assets/route-aliases.json`.

## When to invoke explicitly

- You want to force a specific skill against ambiguous intent.
- You want the heartbeat (bare `quack`) to confirm rubber-duck is loaded.
- You want to bypass auto-routing precedence and pick your own skill.
