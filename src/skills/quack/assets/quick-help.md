# quack quick help

Tell me your route intent: `quack <route> <intent>`.

Example:
  - `quack review this diff: <your diff here>`

Output style:
  - success: `Routing: <skill>.`
  - override success: `Routing: <skill> via <subagent>.`
  - clarification: `Need one detail: <question>`

How to use quack:
  - `quack review this diff`
  - `quack trace this failure`
  - `quack risk this rollout plan`
  - `quack simplify this module`
  - `quack patch this bug with general`

## Options for skills routing

- `duck-review` — changed-code risk review. aliases: `code review`, `pr review`
- `duck-debug` — Socratic root-cause loop + read-only trace mode. aliases: `diagnose`, `trace`, `investigate`, `where used`
- `duck-risk` — failure/rollback/compat stress-test. aliases: `failure modes`, `rollback`
- `duck-simplify` — reduce complexity safely + semantic duplication/divergence review. aliases: `overengineered`, `reduce complexity`, `dry`, `duplication`, `dedupe`, `divergence`
- `duck-patch` — smallest safe bounded implementation. aliases: `fix`, `targeted edit`
- `duck-design` — approach/tradeoff comparison. aliases: `architecture`, `tradeoff`
- `duck-triage` — severity + test-gap prioritization. aliases: `severity`, `prioritize`
- `duck-teach` — concise explain mode + tutorial-style guidance/examples. aliases: `explain`, `what does this do`, `walkthrough`, `decode`, `show me`, `how to`

## Optional Subagent override

- Default subagent: `duckling`
- Override syntax:
  - `quack <intent> use|with|via <subagent> <intent>`
