# Duck Skill Eval Context (Session Handoff)

Updated: 2026-07-04

## Where We Are

- Latest completed full run:
  - `iteration-4-fresh-copilot-llmgrade-norm-v6`
- Latest frozen baseline:
  - `evals/baselines/iteration-4-fresh-copilot-llmgrade-norm-v6-summary.json`

## Latest Metrics (v6 aggregate mean delta)

- `pass_rate`: `0.2508`
- `tokens`: `-731.0`
- `time_seconds`: `-2.07`

v6 improved over v5 on all three aggregate metrics.

## Key Artifacts

- Iteration root:
  - `/tmp/opencode/duck-skill-evals/iteration-4-fresh-copilot-llmgrade-norm-v6/`
- Global benchmark:
  - `/tmp/opencode/duck-skill-evals/iteration-4-fresh-copilot-llmgrade-norm-v6/global-benchmark.json`
- Deltas:
  - `/tmp/opencode/duck-skill-evals/iteration-4-fresh-copilot-llmgrade-norm-v6/delta-vs-iteration-2.json`
  - `/tmp/opencode/duck-skill-evals/iteration-4-fresh-copilot-llmgrade-norm-v6/delta-vs-iteration-3c.json`

## Important Operational Decisions

- Runner path: pinned scripts under `evals/_pinned-skill-eval-scripts/`.
- Provider path: `opencode run --format json` via `model_runner.py`.
- Grading mode: `llm`.
- Token normalization: `calibrated` with sample-based overhead subtraction.
- Env allowlist: `COPILOT_TOKEN`.
- Memory limit: use `--disable-memory-limit` (Bun instability observed with RLIMIT).

## Current Repo State (high level)

- New baseline file added for v6.
- Runbook updated to reflect true-fresh, Copilot-backed process and freeze workflow.

## Suggested Next Steps

1. Stage + commit docs/baseline updates.
2. Run one confirmation full rerun (`v7`) to check drift vs v6.
3. If uplift needed, prioritize targeted mini runs for residual-variance skills.

## Quick Commands

### Run full fresh eval

```bash
python3 "evals/_pinned-skill-eval-scripts/run_fresh.py" \
  --repo-root "/mnt/f/workspace/rubber-duck" \
  --iteration "iteration-4-fresh-copilot-llmgrade-norm-v7" \
  --out-root "/tmp/opencode/duck-skill-evals" \
  --runner-cmd "python3 /mnt/f/workspace/rubber-duck/evals/_pinned-skill-eval-scripts/model_runner.py" \
  --model-id "github-copilot/gpt-5.3-codex" \
  --timeout-sec 180 \
  --memory-mb 1024 \
  --disable-memory-limit \
  --env-allowlist "COPILOT_TOKEN" \
  --grading-mode llm \
  --token-normalization calibrated \
  --token-calibration-samples 3 \
  --compare-a "/tmp/opencode/duck-skill-evals/iteration-2/global-benchmark.json" \
  --compare-b "/tmp/opencode/duck-skill-evals/iteration-4-fresh-copilot-llmgrade-norm-v6/global-benchmark.json"
```

### Freeze a new baseline

```bash
cp "/tmp/opencode/duck-skill-evals/<iteration>/global-benchmark.json" \
  "evals/baselines/<iteration>-summary.json"
```
