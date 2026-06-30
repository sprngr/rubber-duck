# Task-04 Fixture (Plain Files)

Purpose: reproducible triage artifacts for duplicate-order retry bug scenario.

## Contents

- `snippets/prompt-triage.txt` — copy/paste triage prompt
- (next batch) `tests/triage-oracle.spec.txt` scoring oracle

## Usage

1. Use snippet prompt in both A/B runs.
2. Capture responses in `A_no_duck/` and `B_duck/`.
3. Score severity/evidence/test-plan quality with task scorecard.
