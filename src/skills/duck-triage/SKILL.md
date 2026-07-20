---
name: duck-triage
description: >
  Test coverage analysis and bug triage. Find missing tests, assess test
  quality, classify bug severity, suggest test scenarios. Edge case discovery.
  Use when: "test coverage gaps", "what should we test", "triage this bug",
  or "bug severity".
---

Test coverage and bug triage 🦆. Find what tests miss. Classify what bugs matter. Keep language terse and practical.

## Purpose

Classify bug severity and expose missing test coverage with smallest runnable checks.

{{include: skill-snippets/philosophy-guardrails.md}}

Skill-specific delta:
- Recommend severity and test direction; user decides implementation/test-writing actions.

## Activation

Use for test coverage planning, bug severity triage, and pre-PR test recommendations.

## Method

### 1. Clarify context (if repro/spec missing)

{{include: skill-snippets/clarify-first-preflight.md}}
- Ask one targeted clarifying question about missing repro/spec first.

If evidence is missing, include explicit marker:
- `missing evidence:` with concise list (logs/repro steps/release window/affected scope)

### 2. Apply Duck Ladder (test planning)

Before asking for new tests, check:
1. Does behavior already have reliable coverage?
2. Can existing test be extended instead of new file/suite?
3. Smallest runnable check that fails on regression?

### 3. Triage workflow

**For bug severity:**

1. Collect evidence first: repro artifact, failing path, existing test coverage map.
2. Reproduce the reported behavior.
3. Classify using severity matrix (below).
4. Check: is this a regression or pre-existing?
5. Check: does existing test coverage exist? If not, flag missing coverage as contributing factor.
6. Output: severity + brief rationale + which test to add.

**Bug severity classification:**

| Level | Criteria | Action | Examples |
|---|---|---|---|
| 🔴 P0 — Critical | Data loss, security breach, all users blocked | Hotfix immediate | Wrong money sent, API auth bypass |
| 🟠 P1 — High | Major feature broken, workaround exists | Sprint priority | Search broken for one locale |
| 🟡 P2 — Medium | Partial feature broken, degraded UX | Next iteration | Icon misaligned, slow query |
| 🔵 P3 — Low | Cosmetic, edge case, typo | Backlog | Missing comma, label casing |
| ⚪ P4 — Informational | Nice-to-have, not a bug | Discuss | Suggestion, enhancement |

**For test coverage analysis:**

Flag missing tests when:
- Public API without tests
- Side-effect functions without verification
- Error paths (branch coverage, not just happy path)
- External dependencies (no mocks)
- Public interface without contract tests

**Test quality checklist:**
- [ ] Tests verify behavior, not implementation
- [ ] Tests are deterministic (no random, no time dependency)
- [ ] Tests are independent (no hidden ordering)
- [ ] Test names describe the scenario, not the function
- [ ] Assertions are specific ("equals 42" not "truthy")
- [ ] Error paths are tested ("throws", "rejects", "returns error")

**Edge case discovery framework (check for every input/output):**
- Empty (zero, "", [])
- Null/undefined/missing
- Single element (boundary)
- Max/min values
- Invalid types
- Concurrent access
- Cache state (hit, miss, stale)
- Timeout/boundaries

**Test scenarios to suggest:**
- Happy path (one per feature)
- First failure case
- Boundary case (0, max, null, empty)
- Concurrent case (two calls at once)
- Recovery case (fail → retry → success)
- Regression case (if existing bug has a fix)

**Minimum runnable check rule:**
- Non-trivial logic change (branch/loop/parser/money/security path) should leave one runnable check:
  - one focused test, or
  - one assert-style self-check/demo if test framework path is heavy.
- Trivial one-liner with existing coverage may not need new test.
- Never drop core safeguards for brevity:
  {{include: policy-snippets/safety-carveouts.md}}

### 4. Output

Severity + brief rationale + specific test to add.

Include related test paths or explicit "needs test" when absent.

**Formatting rule (deterministic):**
- When proposing tests, use explicit `needs test:` prefix lines (one per scenario)
- Default target: 1-3 `needs test:` lines based on risk/scope (use 3 only for high-risk or multi-surface changes)
- For uncertainty cases, include one `missing evidence:` line with minimum artifacts needed to refine severity

**Bug report format:**
- One-line title: "Component: what fails"
- Steps to reproduce (numbered, runnable)
- Expected vs actual (one line each)
- Severity + rationale
- Related tests (paths) or "needs test"

**Pre-PR vs In-PR:**
- Pre-PR: suggest what to test (`duck-triage` scope)
- In-PR: annotate missing tests inline (`duck-review` 🧪 test: prefix)

## Boundaries

- Triage recommends direction; implementation/test writing requires explicit user approval on bounded scope (handoff does not replace approval).
- In-PR inline review comments route through `duck-review`.
