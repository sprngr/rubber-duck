---
name: duck-triage
description: >
  Test coverage analysis and bug triage. Find missing tests, assess test
  quality, classify bug severity, suggest test scenarios. Edge case discovery.
  Use when: "test coverage", "what to test", "triage this bug", "bug severity",
  or test review.
---

Test coverage and bug triage 🦆. Find what tests miss. Classify what bugs matter. Caveman mode always on.

## Purpose

Classify bug severity and expose missing test coverage with smallest runnable checks.

## Activation / When to Use

Use for test coverage planning, bug severity triage, and pre-PR test recommendations.

## Preflight Checks

If repro/spec context is missing:
- ask up to three targeted clarifying questions first
- state assumptions explicitly before severity/test recommendations

## Method

### Duck Ladder (test planning context)

Before asking for new tests, check:
1) does behavior already have reliable coverage?
2) can existing test be extended instead of new file/suite?
3) smallest runnable check that fails on regression?

### Test Coverage Analysis

### Missing Test Detection

Flag when:
- Public API without tests
- Side-effect functions without verification
- Error paths (branch coverage, not just happy path)
- External dependencies (no mocks)
- Public interface without contract tests

### Test Quality Checklist

- [ ] Tests verify behavior, not implementation
- [ ] Tests are deterministic (no random, no time dependency)
- [ ] Tests are independent (no hidden ordering)
- [ ] Test names describe the scenario, not the function
- [ ] Assertions are specific ("equals 42" not "truthy")
- [ ] Error paths are tested ("throws", "rejects", "returns error")

### Edge Case Discovery Framework

For every input/output, check:
- Empty (zero, "", [])
- Null/undefined/missing
- Single element (boundary)
- Max/min values
- Invalid types
- Concurrent access
- Cache state (hit, miss, stale)
- Timeout/boundaries

### Test Scenarios to Suggest

- Happy path (one per feature)
- First failure case
- Boundary case (0, max, null, empty)
- Concurrent case (two calls at once)
- Recovery case (fail → retry → success)
- Regression case (if existing bug has a fix)

### Minimum Runnable Check Rule

- Non-trivial logic change (branch/loop/parser/money/security path) should leave one runnable check:
  - one focused test, or
  - one assert-style self-check/demo if test framework path is heavy.
- Trivial one-liner with existing coverage may not need new test.
- Never drop trust-boundary/security/data-loss checks for brevity.

## Bug Severity Classification

| Level | Criteria | Action | Examples |
|---|--|-|---|
| 🔴 P0 — Critical | Data loss, security breach, all users blocked | Hotfix immediate | Wrong money sent, API auth bypass |
| 🟠 P1 — High | Major feature broken, workaround exists | Sprint priority | Search broken for one locale |
| 🟡 P2 — Medium | Partial feature broken, degraded UX | Next iteration | Icon misaligned, slow query |
| 🔵 P3 — Low | Cosmetic, edge case, typo | Backlog | Missing comma, label casing |
| ⚪ P4 — Informational | Nice-to-have, not a bug | Discuss | Suggestion, enhancement |


### Triaging Process

0. Collect evidence first: repro artifact, failing path, existing test coverage map.
1. Reproduce the reported behavior
2. Classify using the severity matrix above
3. Check: is this a regression or pre-existing?
4. Check: does existing test coverage exist? If not, flag missing coverage as contributing factor.
5. Output: severity + brief rationale + which test to add

Triage recommends severity and test direction only; implementation/test-writing actions require explicit user approval or handoff.

## Output Format

- severity + brief rationale + specific test to add
- include related test paths or explicit "needs test" when absent

Pre-PR: suggest what to test (`duck-triage` scope).
In-PR: annotate missing tests inline (`duck-review` 🧪 test: prefix).

## Boundaries & Handoffs

- triage recommends direction; implementation/test writing requires explicit approval or handoff
- in-PR inline review comments route through `duck-review`

## Bug Report Format

When reporting:
- One-line title: "Component: what fails"
- Steps to reproduce (numbered, runnable)
- Expected vs actual (one line each)
- Severity + rationale
- Related tests (paths) or "needs test"
