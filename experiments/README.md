# Rubber Duck A/B Experiment Protocol

Head-to-head comparison: **with Rubber Duck** vs **without Rubber Duck** using same task packets.

## Goal

Measure whether Rubber Duck improves decision quality, safety, and rework outcomes under realistic ambiguity.

## Conditions

- **A_no_duck**: standard assistant workflow, no Rubber Duck router/ducklings/skills.
- **B_duck**: Rubber Duck router active with normal policy.

## Controls (must hold constant)

- same repository commit at run start
- same model + settings
- same task packet text
- same time budget
- same evaluator/rubric

## Recommended sample size

- minimum: 6 tasks
- better: 10-20 tasks
- include mixed task types: review/debug/design/triage

## Directory layout

```
experiments/
  README.md
  scorecard-template.md
  task-packet-template.md
  task-01/
    packet.md
    A_no_duck/
      transcript.md
      final_diff.patch
      test_output.txt
      notes.md
    B_duck/
      transcript.md
      final_diff.patch
      test_output.txt
      notes.md
    scorecard.md
```

## Run steps (per task)

1. Reset repo to baseline commit/state.
2. Open clean session for condition A.
3. Paste exact packet content from `task-XX/packet.md`.
4. Execute until outcome or time budget reached.
5. Export transcript + artifacts to `A_no_duck/`.
6. Reset repo back to baseline state.
7. Repeat steps 2-5 for condition B with Rubber Duck active.
8. Score both using `scorecard-template.md`.

## Transcript capture (OpenCode UI + CLI)

Use UI export/history where available, and keep CLI backup when practical.

Minimum required artifacts:
- transcript (`.md` or `.txt`)
- final diff (`git diff > final_diff.patch`)
- test output (`test_output.txt`)

Recommended commands after each run:

```bash
git diff > experiments/task-01/A_no_duck/final_diff.patch
git status --short > experiments/task-01/A_no_duck/notes.md
```

Repeat for `B_duck` path.

## Scoring method

Use `scorecard-template.md`.

Primary metrics:
- acceptance criteria pass rate
- critical/high defect count
- rework loops
- safety boundary preservation

Secondary metrics:
- time-to-first-correct
- assumptions surfaced
- test completeness
- rollback clarity

## Verdict guidance

For each task, compute delta = `B_duck - A_no_duck` on quality metrics.

Interpretation:
- positive delta: Rubber Duck improved outcome
- zero delta: neutral
- negative delta: investigate failure mode

## Common failure-mode tags

- `scope-overreach`
- `silent-execution-attempt`
- `assumption-hidden`
- `trust-boundary-regression`
- `format-only-drift`
- `test-gap`
