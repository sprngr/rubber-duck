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
- Overfit cleanup pass applied across router/ducklings/skills with adaptive strictness for non-mutating analysis.
- Preserved hard safety/approval guardrails for mutating actions.
- V14 boundary reinforced: explicit split required for scope >2 files.
- Review output contract hardened to schema-first format (prefix + location + problem + `Fix:`), with normalization and final self-check.
- V03 formatting regression resolved after adding schema hint + negative→positive formatting examples.
