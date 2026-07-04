# Duck Skill Eval Runbook

This runbook is the canonical process for true-fresh, Copilot-backed duck-skill evals.

## Canonical Paths

- Eval prompts: `evals/duck-*/evals.json`
- Assertion maps: `evals/duck-*/assertions.json`
- Skill docs under test: `skills/duck-*/SKILL.md`
- Orchestrator scripts: `evals/_pinned-skill-eval-scripts/`
- Scratch artifacts: `/tmp/opencode/duck-skill-evals/`
- Frozen baselines: `evals/baselines/`

## Current Baseline State

- Frozen baseline (latest):
  - `evals/baselines/iteration-4-fresh-copilot-llmgrade-norm-v6-summary.json`
- Previous reference baseline:
  - `evals/baselines/iteration-4-fresh-copilot-llmgrade-norm-v4-summary.json`
- Legacy anchor baseline:
  - `evals/baselines/iteration-2-summary.json`

## Prerequisites

Required:
- `python3`
- `opencode` CLI available on `PATH`
- Copilot auth token exported (allowlisted key in runner): `COPILOT_TOKEN`

Recommended preflight:

```bash
make build && make check
```

## True-Fresh Full Run (All Skills)

Run from repo root.

```bash
python3 "evals/_pinned-skill-eval-scripts/run_fresh.py" \
  --repo-root "/mnt/f/workspace/rubber-duck" \
  --iteration "<new-iteration-name>" \
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

Notes:
- `--disable-memory-limit` is currently required for Bun/opencode stability in this environment.
- Keep writes scoped under `/tmp/opencode/duck-skill-evals/<iteration>`.

## Optional Mini Runs (Targeted Skills)

Use `--skills` to limit scope, e.g.:

```bash
--skills "duck-teach,duck-debt"
```

Everything else stays identical to full run.

## Expected Artifacts

For each iteration directory:

- `<iteration>/manifest.json`
- `<iteration>/run-log.jsonl`
- `<iteration>/global-benchmark.json`
- `<iteration>/delta-vs-*.json`
- `<iteration>/<skill>/benchmark.json`
- `<iteration>/<skill>/eval-<id>/{with_skill,without_skill}/outputs/response.txt`
- `<iteration>/<skill>/eval-<id>/{with_skill,without_skill}/timing.json`
- `<iteration>/<skill>/eval-<id>/{with_skill,without_skill}/grading.json`

## Compare + Decision Flow

1. Read `<iteration>/global-benchmark.json`.
2. Read both delta files (`delta-vs-*.json`).
3. Check aggregate and per-skill deltas:
   - pass rate should not regress materially
   - tokens/time should stay improved or neutral
4. If acceptable, freeze summary to `evals/baselines/`.

## Freeze Baseline Procedure

```bash
cp "/tmp/opencode/duck-skill-evals/<iteration>/global-benchmark.json" \
  "evals/baselines/<iteration>-summary.json"
```

Then verify:

```bash
git status --short -- "evals/baselines/<iteration>-summary.json"
```

## Troubleshooting

- `runner failed` / provider crashes:
  - keep `--disable-memory-limit`
  - verify `opencode` works interactively
- missing auth:
  - ensure `COPILOT_TOKEN` is exported and allowlisted
- empty/invalid judge output:
  - rerun; judge parser expects strict JSON object payload
- no metric movement:
  - adjust prompts/assertions semantics, not just wording noise

## Handoff Checklist

Before ending a session, record:
- latest completed iteration name
- benchmark + delta file paths
- whether a baseline was frozen
- open next actions (rerun, targeted skill tuning, commit plan)
