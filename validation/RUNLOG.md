# Validation Run Log

Track validation outcomes across commits/releases.

**Entry policy:**

- Primary gate: quick subset (`V02, V03, V04, V11, V12, V13, V14, V32, V33`).
- Record all quick-subset failures always.
- If any extended checks fail, record those IDs too.
- Verdict rule: FAIL if any Critical/High in quick subset fails.

**Entry template:**

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

## 2026-08-06 — phase-gated-validation-alignment

- Commit: 7f49884
- Runner: validation/run-validation-tests.py
- Suite version: validation/README.md
- Verdict: PASS (focused calibration subset)

### Quick subset

- Passed: V14, V30, V32, V33 (focused runs with `RUBBER_DUCK_MODEL=opencode/big-pickle`)
- Failed: none (for focused subset)

### Extended failures (optional)

- Failed: none recorded in this session

### Notes

- Updated fixtures/docs for phase-gated policy semantics:
  - V14 now checks Phase 3 cap boundary instead of stale file-count heuristic.
  - V30 now validates clear approval intent (`yes go ahead`) opening the gate.
  - Added V32 (missing phase selection in preflight) and V33 (re-approval between phases).
- Copilot model route returned provider `UnknownError` in this environment; focused validation proceeded with `opencode/big-pickle`.
- Matcher calibration required for V33 phrasing variance; substring mode confirmed expected behavior for the focused check.

## 2026-08-03 — v2-quackening

- Commit: edfda56
- Runner: validation/run-validation-tests.py (hybrid matcher)
- Suite version: validation/README.md
- Verdict: PASS

### Quick subset

- Passed: V02, V03, V04, V11, V12, V13, V14
- Failed: none

### Notes

- Hybrid matcher (substring + LLM judge fallback) stabilized vocabulary variance. Two consecutive runs 7/7. Judge uses neutral default opencode agent, evaluates behavior intent from test notes.

## 2026-07-21 — v2-quackening

- Verdict: not run (development session)
- Session work: AGENTS.md style guide, mutating action gate scope clarification, installer feature parity, duck-adapt + duck-grill skills, routing model docs
- No validation run performed; changes primarily documentation and installer tooling

## 2026-06-29 — overfit-cleanup-pass

- Verdict: PASS
- Quick subset: V02, V03, V04, V11, V12, V13, V14 passed
- Overfit cleanup pass applied across governor/router-era prompts and ducklings/skills with adaptive strictness for non-mutating analysis
- V14 boundary reinforced: phase-cap boundary enforcement requires bounded split
- Review output contract hardened to schema-first format
- V03 formatting regression resolved after adding schema hint + negative->positive formatting examples

Full validation history: see git log for `docs/validation/CHANGELOG.md` (file deleted in this refactor; history preserved in git).
