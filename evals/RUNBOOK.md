# Duck Skill Eval Runbook

This runbook standardizes how to run skill evals for the duck skills with reproducible artifacts.

## Scope

- Full runs for all 7 duck skills
- Mini A/B runs for targeted tuning
- Deterministic + LLM grading
- Benchmark aggregation and baseline freeze workflow

## Canonical Paths

- Eval configs: `evals/duck-*/evals.json`
- Assertion maps: `evals/duck-*/assertions.json`
- Pinned scripts: `evals/_pinned-skill-eval-scripts/`
- Default scratch workspace (run with OpenCode harness): `/tmp/opencode/duck-skill-evals/`
- Baselines in repo: `evals/baselines/`

Build integration reference:
- `scripts/README.md` (see harness artifact build + make targets)

## Prerequisites

Required:
- `python3`
- Shell access

Optional but useful:
- `jq`

## Workspace Layout (expected)

For each run (example: `iteration-3`):

`/tmp/opencode/duck-skill-evals/iteration-3/<skill>/eval-<id>/{with_skill,without_skill}/`

Each variant directory should contain:
- `outputs/response.txt`
- `timing.json`
- `grading.json`

Each skill directory should contain:
- `benchmark.json`

Run root should contain:
- `global-benchmark.json`
- `delta-vs-iteration-2.json` (or equivalent comparison file)

## Full Run (All Skills)

1. Pick iteration workspace, e.g.:
   - `/tmp/opencode/duck-skill-evals/iteration-3`

2. For each skill in:
   - `duck-debug`, `duck-review`, `duck-explain`, `duck-teach`, `duck-design`, `duck-triage`, `duck-debt`

3. For each eval ID in `evals/duck-<skill>/evals.json`:
   - Generate `with_skill` response from the skill doc under `skills/duck-<skill>/SKILL.md`
   - Generate `without_skill` baseline response without loading skill instructions
   - Write `outputs/response.txt`
   - Write `timing.json` with numeric fields:
     - `total_tokens`
     - `duration_ms`

4. Build `grading.json` for both variants:
   - Apply deterministic checks where possible
   - Grade all `type=llm` assertions with evidence snippets

5. Aggregate per-skill benchmark:

```bash
"evals/_pinned-skill-eval-scripts/aggregate-benchmark.sh" "/tmp/opencode/duck-skill-evals/iteration-3/<skill>"
```

6. Build run-level `global-benchmark.json` by combining all skill benchmarks.

7. Compare to iteration-2 baseline:
- baseline source: `/tmp/opencode/duck-skill-evals/iteration-2/global-benchmark.json`
- output: `/tmp/opencode/duck-skill-evals/iteration-3/delta-vs-iteration-2.json`

Optional preflight (recommended):

```bash
make build
make check
```

## Mini A/B Runs (Targeted)

Use mini runs before full reruns for fast iteration.

Recommended mini sets:
- `iteration-3-mini` → `duck-debug`, `duck-design`
- `iteration-3-mini-2` → `duck-explain`, `duck-teach`
- `iteration-3-mini-3/4/5/...` → targeted regressions (e.g., `duck-review`, `duck-triage`)

Process is identical to full run but restricted to selected skills.

## Target Gates (Current)

Use these acceptance gates for optimization iterations:

- `pass_rate` mean delta: `>= 0.80`
- `tokens` mean delta: `<= 45`
- `time_seconds` mean delta: `<= 0.50`

If any gate fails, do not freeze as full baseline.

## Baseline Freeze Procedure

1. Confirm target gates status.
2. Copy summary into repo baseline file (example):

```bash
cp "/tmp/opencode/duck-skill-evals/iteration-3/global-benchmark.json" \
  "evals/baselines/iteration-3-summary.json"
```

3. Commit only intended files (explicitly stage paths).

## Partial Freeze Procedure

If full gates fail but subset improves:

1. Keep optimized skill docs for winning skills.
2. Revert non-winning skills to prior behavior profile.
3. Re-run mini checks for reverted skills.
4. Commit only selected skill docs with explicit commit message.

## Troubleshooting

- Missing workspace output:
  - Verify run root exists under `/tmp/opencode/duck-skill-evals/`.
- Empty/invalid grading:
  - Ensure assertion map is converted to per-eval assertion list before deterministic grader.
- No metric movement after assertion tweaks:
  - Prompt separation likely too weak; redesign eval prompts, not only assertion wording.
- Pass-rate drops with token wins:
  - Roll back compression for affected skills; keep selective optimization.

## Notes

- Keep repo baselines small (summary JSON preferred over full artifact copies).
- Treat `/tmp/opencode` artifacts as ephemeral unless explicitly promoted to repo.
