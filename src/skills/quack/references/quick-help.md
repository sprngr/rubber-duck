# quack quick help

Output style:
  - success: `Routing: <skill>.`
  - override success: `Routing: <skill> via <subagent>.`
  - clarification: `Need one detail: <question>`

Tell me your route intent: `quack <route> <intent>`.

Example:
  - `quack review this diff: <your diff here>`

How to use quack:
  - `quack review this diff`
  - `quack trace this failure`
  - `quack risk this rollout plan`
  - `quack simplify this module`
  - `quack patch this bug with general`

## Options for skills routing

- `duck-review` — changed-code risk review. aliases: `code review`, `pr review`
- `duck-trace` — read-only defs/refs/callers/tests/imports. aliases: `investigate`, `where used`
- `duck-risk` — failure/rollback/compat stress-test. aliases: `failure modes`, `rollback`
- `duck-simplify` — reduce complexity safely. aliases: `overengineered`, `reduce complexity`
- `duck-dry-review` — semantic duplication/divergence. aliases: `duplication`, `dedupe`
- `duck-patch` — smallest safe bounded implementation. aliases: `fix`, `targeted edit`
- `duck-debug` — Socratic root-cause loop. aliases: `diagnose`, `trace`
- `duck-design` — approach/tradeoff comparison. aliases: `architecture`, `tradeoff`
- `duck-triage` — severity + test-gap prioritization. aliases: `severity`, `prioritize`
- `duck-explain` — concise behavior walkthrough. aliases: `walkthrough`, `decode`
- `duck-teach` — tutorial-style guidance/examples. aliases: `show me`, `how to`

## Optional Subagent override

- Default subagent: `duckling`
- Override syntax:
  - `quack <intent> use|with|via <subagent> <intent>`
