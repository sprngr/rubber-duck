# quack quick help

Usage: `quack <intent>`

Examples:
  - `quack review this diff`
  - `quack trace where this is used`
  - `quack what could break in this rollout`
  - `quack simplify this module`
  - `quack fix this bug`

Output:
  - `Routing: <skill>.` — matched and routing
  - `Need one detail: <question>` — needs clarification

## Available routes

- **debug** — root-cause questions + trace evidence (`trace`, `investigate`, `where is this used`, `map callers`)
- **review** — code/diff risk review (`code review`, `review the diff`)
- **design** — tradeoff comparison (`architecture`, `tradeoffs`, `help me choose`)
- **teach** — explain + tutorials (`explain`, `show me`, `walk me through`)
- **triage** — test gaps + bug severity (`test gaps`, `what should we test`, `bug severity`)
- **risk** — failure modes + rollback safety (`stress test`, `what could break`, `rollback risk`)
- **simplify** — complexity reduction + deduplication (`dedupe`, `dry`, `overengineered`, `reduce complexity`)
- **patch** — small bounded edits (`fix`, `apply this fix`, `targeted edit`)
- **refactor** — multi-file restructuring (`extract function`, `rename across files`, `move to another file`, `inline`)
- **debt** — deferred-work audit (`duck debt`, `what did we defer`, `todo review`)

## Advanced: subagent override

Force a specific subagent: `quack <intent> via <subagent>`

Example: `quack fix this bug via general`
