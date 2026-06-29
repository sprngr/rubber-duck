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

## 2026-06-28 — bootstrap

- Commit: uncommitted-working-tree
- Runner: local
- Suite version: docs/validation/README.md
- Verdict: PASS (example)

### Quick subset
- Passed: V02, V03, V04, V11, V12, V13, V14
- Failed: none

### Extended failures (optional)
- Failed: none

### Notes
- Baseline entry format established.
- Replace this bootstrap row with first real validation run.
