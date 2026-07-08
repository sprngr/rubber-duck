# Routing Matrix (Duck Ambient Router)

Purpose: lightweight regression matrix for `routeAmbient()`.
Use this when tuning keyword buckets or tie-break priority.

## Priority tie-break (when scores tie)

`triage > debug > review > explain > teach > design`

## Cases

| Input | Expected intent | Expected primary agent | Notes |
|---|---|---|---|
| `What should we test before PR?` | `triage` | `duck-investigator` | test planning signal |
| `Need inline PR comments for test gaps` | `triage` | `duck-reviewer` | triage + inline-comment signal |
| `Why is this endpoint returning 500?` | `debug` | `duck-investigator` | failure signal |
| `Intermittent flaky error, hard to reproduce` | `debug` | `duck-investigator` | repro-weak meta should include triage skill |
| `Small bounded patch in 1-2 files to fix bug` | `debug` | `duck-investigator` | bounded patch should append builder in execution chain |
| `Review this diff for risky changes` | `review` | `duck-reviewer` | review signal |
| `Audit these changes; looks like copy paste` | `review` | `duck-reviewer` | duplication signal should append duck-dry |
| `Explain what this function does` | `explain` | `duck-investigator` | explain signal |
| `Teach me how this cache layer works` | `teach` | `duck-simple` | teach signal |
| `Help me choose architecture tradeoffs` | `design` | `duck-simple` | design signal |
| `Need design review; bug risk and repeated logic` | `design` | `duck-simple` | duplication should append duck-dry, issue should include debug skill meta |
| `Hello there` | `null` | n/a | pass-through (no subagent) |

## Manual check workflow

1. Launch Pi with extension.
2. For each input above, run:

```text
/duck route <input>
```

3. Verify route + reason are stable.
4. For complex chain behavior, inspect `routeAmbient()` output in code-level checks before release.
