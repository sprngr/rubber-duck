# Quack Route Examples

Use this file when:
- user asks for example route outputs
- route choice is unclear and concrete option shape helps
- operator wants chain hint wording consistency checks

## Example 1 — Runtime bug request

Input:

`quack endpoint returns 500 when userId missing`

Output shape:

- `A | route=duck-debug | best_for=runtime breakage/root-cause tracing | tradeoff=slower than quick scan | chain=duck-debug -> duck-investigator -> duck-triage? -> duck-builder(on explicit patch request)`
- `B | route=duck-review | best_for=diff risk scan and concrete review comments | tradeoff=less runtime diagnosis depth | chain=duck-review -> duck-reviewer + duck-adversary + duck-simple (+ duck-dry signal) (+ duck-triage test-gap)`
- `Recommended: A — runtime failure signal with missing-behavior gap is best handled by debug evidence flow first.`
- `Pick route: A or B?`

## Example 2 — Diff review request

Input:

`quack review this diff for correctness and rollback risk`

Output shape:

- `A | route=duck-review | best_for=risk-first diff findings | tradeoff=less runtime trace depth | chain=duck-review -> duck-reviewer + duck-adversary + duck-simple (+ duck-dry signal) (+ duck-triage test-gap)`
- `B | route=duck-debug | best_for=runtime reproduction/root-cause trace | tradeoff=slower for static diff-only checks | chain=duck-debug -> duck-investigator -> duck-triage? -> duck-builder(on explicit patch request)`
- `Recommended: A — request is diff-centric and rollback-aware review.`
- `Pick route: A or B?`

## Example 3 — Bare heartbeat

Input:

`quack`

Output shape:

- `🦆 Ready. Explicit routing is active.`
- `What should I route: review, debug, design, explain, teach, or triage?`
