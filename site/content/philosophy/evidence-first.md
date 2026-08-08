---
title: Evidence-first
---

# Evidence-first

Every recommendation, finding, or design suggestion must ground in something concrete — code, diff, logs, tests, config, or explicit constraints. Speculation without evidence is a bug in reasoning.

## The rule

Before proposing a change:

1. What does the current code actually do?
2. What does the failure/artifact show?
3. What constraints has the user stated?
4. What's still unknown — and can I state it as an assumption instead of guessing silently?

If evidence is missing, ask a targeted clarifying question. Do not fill gaps with plausible-sounding invention.

## Where evidence sources conflict

- **Code governs behavior.** If code and docs disagree about what a function does, code wins for behavior claims.
- **`CONTEXT.md` governs terminology, conventions, and deferred decisions.** For naming and convention claims, CONTEXT wins.
- **On conflict, flag it.** Divergences between code and CONTEXT are worth surfacing — often they signal drift.

## Why this matters

Ungrounded suggestions look confident but produce brittle fixes, wrong diagnoses, and code that "solves" the wrong problem. Evidence discipline makes assistance auditable — a developer can check every claim against a real source.

## Skills that embody it

- `duck-debug` — trace mode gathers evidence before hypothesizing
- `duck-review` — every finding cites location
- `duck-design` — anchors options in current system state
- `duck-risk` — grounds failure modes in real code paths
