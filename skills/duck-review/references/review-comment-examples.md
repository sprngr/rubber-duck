# Duck Review Comment Examples

Load this file when prefix choice unclear or reviewer needs calibrated phrasing.

## Canonical one-line template

`<prefix> <path[:line]> — <problem>. Fix: <smallest safe change>.`

## Examples by prefix

- `🔒 sec: services/oauth/callback.ts:61 — redirect_url accepted without allowlist enables open redirect. Fix: enforce allowlisted host validation before redirect.`
- `⚠️ bug: api/orders.ts:142 — null orderTotal reaches tax calc and throws. Fix: guard null and return 400 before tax computation.`
- `⚡ perf: jobs/reconcile.ts:97 — per-row DB call creates N+1 on large batches. Fix: bulk-fetch records once and map in memory.`
- `🧪 test: src/cache/refresh.ts:55 — stale-cache fallback path untested. Fix: add test for stale hit then async refresh.`
- `📝 doc: docs/auth.md:34 — token rotation behavior changed but docs still describe static token. Fix: update auth flow section with rotation semantics.`

## Prefix priority

If one finding could fit several prefixes, pick highest risk:

1. `🔒 sec:`
2. correctness/data-loss prefix (`⚠️ bug:`)
3. `⚡ perf:`
4. `🧪 test:`
5. `📝 doc:`

## Anti-patterns to avoid

- Vague: "consider improving this".
- Missing fix direction.
- Multiple unrelated issues in one comment line.
- Nitpicks before high-risk findings.
