# Quack Runtime Smokecheck

Run these prompts manually and verify output shape.

## 1) Bare heartbeat

Input:
- `quack`

Expect:
- one-line heartbeat from static asset
- quick-help block
- one route-intent prompt
- no ad-hoc/random quip text

## 2) Normal success

Input:
- `quack review this diff`

Expect:
- `Routing: duck-review.`
- routes immediately (no route menu)

## 3) Prefix separator tolerance

Input:
- `quack: review this diff`
- `quack - review this diff`
- `quack — review this diff`

Expect:
- same behavior as normal success

## 4) Quoted intent tolerance

Input:
- `quack "review this diff"`
- `quack: "risk this rollout"`
- `quack 'trace this failure'`

Expect:
- outer quote pair stripped
- routes normally

## 5) Trailing punctuation tolerance

Input:
- `quack review this diff?`
- `quack risk this rollout!!!`

Expect:
- trailing punctuation stripped
- routes as if clean intent was provided

## 6) Invalid override path

Input:
- `quack review with badagent`

Expect:
- exactly one corrective question:
  - `Need one detail: unknown subagent "badagent". Use duckling or general?`
- no routing until corrected

## 7) Optional compliance trace spot-check

Input:
- ask for debug/compliance trace explicitly with a resolvable route

Expect:
- success may include `ROUTE_EXEC` only when trace is explicitly requested
- success should stay minimal by default
