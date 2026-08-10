# Rubber Duck Validation Context

## Purpose

Behavior regression suite for Rubber Duck governor + skills. Verifies governor gates (clarify-first, execution approval, safety carve-outs), skill routing, and delegated skill behavior via real harness execution.

## Structure

- `test-prompts.json` — 35 tests (V01-V35), machine-readable
- `run-validation-tests.py` — automated runner (opencode harness, bwrap sandbox, fixtures, multi-turn)
- `fixtures/` — 9 synthetic workspace clusters for evidence-grounded tests
- `README.md` — test catalog, runbook, smokecheck, automated testing docs

## Test categories

- **Critical (10):** V02, V11, V12, V13, V29, V30, V31, V32, V33, V34 — approval gates, safety carve-outs, no silent execution
- **High (17):** V03-V04, V07-V09, V14-V16, V19-V24, V26-V27, V35 — routing, boundary compliance, skill behavior
- **Medium (8):** V01, V05-V06, V10, V17-V18, V25, V28 — style, formatting, heartbeat

## Runner features

- **Dependencies**: opencode CLI (>= 1.18), bubblewrap (optional, sandbox), Python 3.9+ (stdlib only)
- Isolated temp workspace per test (bwrap sandbox by default, `--sandbox none` fallback)
- Per-test fixture loading (synthetic codebases copied into workspace)
- Multi-turn support via `follow_ups` field + `opencode run --session <id>`
- `--auto` flag enables tool use within sandbox
- Signal matching: case-insensitive substring, all expected signals must be present
- Full responses saved to `$RESULTS_DIR/<ID>.json`

## Pass rate state

**As of 2026-08-02:**

- Best run: 23/31 (74%) — run6
- Typical range: 18-23/31 (58-74%) across calibration runs
- Stable passes: 16 tests pass consistently across all runs
- Volatile: 15 tests pass/fail depending on LLM vocab variance

**Known limitation:** Signal matching uses exact substring. Agent uses different vocabulary each invocation, causing non-deterministic pass/fail for tests where behavior is correct but wording shifts. This is LLM non-determinism, not signal accuracy failure.

## Signal calibration approach

- Lenient vocabulary matching — accept behavior variance, calibrate signals to observed responses
- Stem matching where possible (e.g., "duplicat" matches "duplication" and "duplicated")
- Prioritize behavior intent over exact wording
- Critical test signals favor robust gate vocabulary ("approve", "refuse", "trust")

## Conventions

- Test IDs: V01-V35, sequential, never reused
- Fixtures: synthetic but realistic, committed (`.duck-tape/.gitignore` files have `*` commented out)
- Severity tags: Critical / High / Medium
- `follow_ups` capped at 5 turns (`--max-follow-up-turns`)

## Open questions

- Switch matcher from substring to semantic similarity (embeddings) for stable pass rate?
- Add `--severity` filter to CI runs for Critical-only gate enforcement?
- Add per-harness test execution (Claude, Copilot) beyond opencode?
