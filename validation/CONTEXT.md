# Rubber Duck Validation Context

## Purpose

Behavior regression suite for Rubber Duck governor + skills. Verifies governor gates (clarify-first, execution approval, safety carve-outs), skill routing, and delegated skill behavior via real harness execution.

## Structure

- `test-prompts.json` — 53 tests (V01-V53), machine-readable
- `run-validation-tests.py` — automated runner (opencode harness, bwrap sandbox, fixtures, multi-turn)
- `fixtures/` — 11 synthetic workspace clusters for evidence-grounded tests
- `README.md` — test catalog, runbook, smokecheck, automated testing docs

## Test categories

- **Critical (19):** V02, V11, V12, V13, V29, V30, V31, V32, V33, V34, V40, V42, V44, V48, V49, V50, V51, V52, V53 — approval gates, safety carve-outs, no silent execution, no overreach, Enforcement Bootstrap
- **High (23):** V03-V04, V07-V09, V14-V16, V19-V24, V26-V27, V35-V37, V41, V43, V45-V47 — routing, boundary compliance, skill behavior, Duck Ladder, Auto-Clarity, Interaction Contract, Socratic challenge, fallback path
- **Medium (10):** V01, V05-V06, V10, V17-V18, V25, V28, V38-V39 — style, formatting, heartbeat, debt markers, CONTEXT.md loading

## Runner features

- **Dependencies**: opencode CLI (>= 1.18), bubblewrap (optional, sandbox), Python 3.9+ (stdlib only)
- Isolated temp workspace per test (bwrap sandbox by default, `--sandbox none` fallback)
- Per-test fixture loading (synthetic codebases copied into workspace)
- Multi-turn support via `follow_ups` field + `opencode run --session <id>`
- `--auto` flag enables tool use within sandbox
- Signal matching: case-insensitive substring, all expected signals must be present
- Full responses saved to `$RESULTS_DIR/<ID>.json`

## Fixtures

| Fixture | Tests | Contents |
|---|---|---|
| `shared` | (referenced by auth, monolith, rollout, tape-state, tape-marker) | `CONTEXT.md`, `docs/adr/ADR-001-db-choice.md` |
| `auth` | V02, V23, V42, V46 | `src/auth/{middleware,token,routes}.ts` with auth bug + JWT surface |
| `app` | V06 | `src/{container,logger}.ts`, `src/services/{userService,emailService}.ts` with DI pattern |
| `monolith` | V07 | `src/{main,db,auth,orders,billing}.ts` with shared DB coupling |
| `parser` | V08 | `src/parser.ts`, `tests/parser.test.ts` with CSV parser + missing test scenarios |
| `validation` | V10, V24 | `src/validators/{user,order,payment}Validator.ts` with duplicated validation logic |
| `rollout` | V22, V34, V35 | `deploy.yaml`, `docs/adr/ADR-002-rollout.md` with RISK comments + tradeoffs |
| `tape-state` | V26 | `CONTEXT.md`, `.duck-tape/.gitignore` for state-only mode |
| `tape-marker` | V27 | `CONTEXT.md`, `.duck-tape/.gitignore`, `.duck-tape/.last-compact`, `.duck-tape/2024-04-15-1030.state.md` |
| `security-vuln` | V36, V37, V38 | `src/users.ts` with SQL injection + auth escalation bugs, `src/db.ts` |
| `context-loading` | V39 | `CONTEXT.md` with project conventions (parameterized queries, auth middleware rules) |

## Pass rate state

**As of 2026-08-17:**

- Suite size: 53 tests
- Previous best: 23/31 (74%) on original 35-test suite
- New tests (V36-V48) not yet calibrated against live execution
- V52-V53 (Enforcement Bootstrap coverage) added post v3.0.0, not yet calibrated

**Known limitation:** Signal matching uses exact substring. Agent uses different vocabulary each invocation, causing non-deterministic pass/fail for tests where behavior is correct but wording shifts. This is LLM non-determinism, not signal accuracy failure.

## Signal calibration approach

- Lenient vocabulary matching — accept behavior variance, calibrate signals to observed responses
- Stem matching where possible (e.g., "duplicat" matches "duplication" and "duplicated")
- Prioritize behavior intent over exact wording
- Critical test signals favor robust gate vocabulary ("approve", "refuse", "trust")

## Conventions

- Test IDs: V01-V51, sequential, never reused
- Fixtures: synthetic but realistic, committed (`.duck-tape/.gitignore` files have `*` commented out)
- Severity tags: Critical / High / Medium
- `follow_ups` capped at 5 turns (`--max-follow-up-turns`)

## Open questions

- Switch matcher from substring to semantic similarity (embeddings) for stable pass rate?
- Add `--severity` filter to CI runs for Critical-only gate enforcement?
- Add per-harness test execution (Claude, Copilot) beyond opencode?
