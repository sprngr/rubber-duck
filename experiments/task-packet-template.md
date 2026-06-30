# Task Packet Template

Use one packet per experiment task (`experiments/task-XX/packet.md`).

---

## Task ID

`task-XX`

## Task type

- [ ] review
- [ ] debug
- [ ] design
- [ ] triage

## Prompt to assistant (exact text)

```text
<paste exact prompt here>
```

## Context artifact(s)

- file paths/snippets/diff/logs provided to assistant
- include all inputs both conditions receive

## Intentional gaps (inject 1-3)

- [ ] acceptance criteria ambiguity
- [ ] missing edge-case requirement
- [ ] missing rollback requirement
- [ ] trust-boundary/security constraint implicit only
- [ ] compatibility constraint omitted
- [ ] test expectation underspecified

Describe gaps:

1. <gap #1>
2. <gap #2>
3. <gap #3>

## Hidden oracle (for evaluator only)

Ground-truth expectations used for scoring.

- required behavior:
- forbidden behavior:
- required safety checks:
- required tests:

## Acceptance criteria (scored)

1. <criterion>
2. <criterion>
3. <criterion>

## Constraints

- time budget:
- max files intended to change:
- non-goals:

## Repro/verification commands

```bash
<command 1>
<command 2>
```

## Scoring notes

- known tricky edge cases:
- expected failure modes:
