# Duck Skill Eval Baseline Comparison

Updated: 2026-07-04

## Aggregate Mean Delta Comparison

Higher `pass_rate` is better. Lower `tokens` and `time_seconds` are better.

| Baseline | pass_rate | tokens | time_seconds |
|---|---:|---:|---:|
| iteration-2 | 0.8373 | 65.1 | 0.49 |
| iteration-3c | 0.7619 | 49.1 | 0.20 |
| iteration-4-fresh-copilot-llmgrade-norm-v4 | 0.1873 | -1060.7 | -1.30 |
| iteration-4-fresh-copilot-llmgrade-norm-v5 | 0.1865 | -696.9 | -1.61 |
| iteration-4-fresh-copilot-llmgrade-norm-v6 | 0.2508 | -731.0 | -2.07 |

## Recent Progress (Normalized Track)

- v4 → v5:
  - pass_rate: `-0.0008`
  - tokens: `+363.8` (worse)
  - time_seconds: `-0.31` (better)
- v5 → v6:
  - pass_rate: `+0.0643` (better)
  - tokens: `-34.1` (better)
  - time_seconds: `-0.46` (better)
- v4 → v6:
  - pass_rate: `+0.0635` (better)
  - tokens: `+329.7` (worse vs v4)
  - time_seconds: `-0.77` (better)

## Skill-Level Highlights (v4 → v5 → v6 pass delta)

- `duck-triage`: `0.2222 → -0.1111 → 0.6667` (major recovery)
- `duck-teach`: `0.1111 → 0.3056 → 0.0` (variance/regression in v6)
- `duck-debt`: `0.0 → 0.3333 → 0.2222` (improved vs v4, slight dip vs v5)

## Methodology Change Note (Important)

Direct comparison between legacy baselines (`iteration-2`, `iteration-3c`) and the later normalized Copilot track (`iteration-4-fresh-copilot-llmgrade-norm-*`) is **not apples-to-apples** due to methodology changes:

- moved to true-fresh runner path (`run_fresh.py`)
- Copilot backend via `opencode run --format json`
- in-run `llm` grading path
- calibrated token normalization (overhead subtraction)
- operational use of `--disable-memory-limit` for Bun/opencode stability

Decision guidance:
- Use `v4/v5/v6` for primary optimization decisions.
- Keep `iteration-2` and `iteration-3c` as historical reference anchors only.
