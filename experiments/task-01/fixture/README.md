# Task-01 Fixture (Plain Files)

Purpose: reproducible code artifacts for the review-heavy experiment task.

## Contents

- `src/auth/parseAge.ts` — baseline safe parser
- `src/auth/register.ts` — baseline request validation
- `diffs/regression.patch` — intentionally risky change used in packet
- `tests/parseAge.spec.txt` — plain-text test scenarios
- `tests/register.spec.txt` — plain-text test scenarios
- `snippets/prompt-review-diff.txt` — copy/paste prompt block

## Usage

1. Copy `src/` into your run workspace.
2. Apply `diffs/regression.patch` (or paste from snippet) for review task.
3. Use `tests/*.spec.txt` as expected-behavior oracle during scoring.
