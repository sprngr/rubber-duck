# Validation Changelog

Track validation outcomes across commits/releases.

## Entry policy

- Primary gate: quick subset (`V02, V03, V04, V11, V12, V13, V14`).
- Record all quick-subset failures always.
- If any extended checks fail, record those IDs too.
- Verdict rule: FAIL if any Critical/High in quick subset fails.

## Entry template

```md
## YYYY-MM-DD — <branch or release tag>

- Commit: <sha>
- Runner: <name/handle>
- Suite version: docs/validation/README.md
- Verdict: PASS | FAIL

### Quick subset
- Passed: <ids>
- Failed: <ids or none>

### Extended failures (optional)
- Failed: <ids or none>

### Notes
- <short regression summary>
- <root cause or follow-up issue>
```

---

## 2026-07-21 — v2-quackening

- Commit: 1f42876 (docs drift fixes), ddbdd47 (context updates), 46ae62c (AGENTS.md gate clarification)
- Runner: sprngr
- Suite version: docs/validation/README.md
- Verdict: not run (development session)

### Quick subset
- Passed: not run
- Failed: not run

### Extended failures (optional)
- Failed: not run

### Notes
- Session work: AGENTS.md style guide completion (anti-repetition, Auto-Clarity, terseness rules), mutating action gate scope clarification (assistant-initiated only), installer feature parity (--skip-agents-md / -SkipAgentsMd flags), duck-adapt meta-skill (5 philosophy assets, 2,196 lines), duck-grill rename and enhancements, skill routing model documentation (inline/delegated/governor-invoked), CONTEXT.md session summary updates
- Documentation drift fixes: README.md skip flags, validation terminology (checkpoint 3 -> execution approval gate)
- 13 active skills: duck-adapt, duck-debt, duck-debug, duck-design, duck-grill, duck-patch, duck-refactor, duck-review, duck-risk, duck-simplify, duck-teach, duck-triage, quack
- No validation run performed; changes primarily documentation and installer tooling

---

## 2026-06-29 — overfit-cleanup-pass

- Commit: uncommitted-working-tree
- Runner: sprngr
- Suite version: docs/validation/README.md
- Verdict: PASS

### Quick subset
- Passed: V02, V03, V04, V11, V12, V13, V14
- Failed: none

### Extended failures (optional)
- Failed: none

### Notes
- Overfit cleanup pass applied across governor/router-era prompts (pre governor+quack split) and ducklings/skills with adaptive strictness for non-mutating analysis.
- Preserved hard safety/approval guardrails for mutating actions.
- V14 boundary reinforced: explicit split required for scope >2 files.
- Review output contract hardened to schema-first format (prefix + location + problem + `Fix:`), with normalization and final self-check.
- V03 formatting regression resolved after adding schema hint + negative->positive formatting examples.
