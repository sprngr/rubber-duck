# Duck Skill Eval Baseline Comparison

Updated: 2026-07-04

## Aggregate Mean Delta Comparison

Higher `pass_rate` is better. Lower `tokens` and `time_seconds` are better.

| Baseline | pass_rate | tokens | time_seconds |
|---|---:|---:|---:|
| iteration-2 | 0.8373 | 65.1 | 0.49 |
| norm-v4 | 0.1873 | -1060.7 | -1.30 |
| norm-v5 | 0.1865 | -696.9 | -1.61 |
| norm-v6 | 0.2508 | -731.0 | -2.07 |

## Progression

- norm-v4 → norm-v5:
  - pass_rate: `-0.0008`
  - tokens: `+363.8`
  - time_seconds: `-0.31`
- norm-v5 → norm-v6:
  - pass_rate: `+0.0643`
  - tokens: `-34.1`
  - time_seconds: `-0.46`

## Methodology Change Note

Legacy baselines and normalized Copilot true-fresh runs are not strictly apples-to-apples. Methodology changed (runner path, LLM grading mode, and calibrated token normalization). Use normalized-track comparisons for primary optimization decisions.
