# Instruction Optimization Baseline (Pass 0)

Date: 2026-07-04
Run id: `instruction-opt-pass0`
Machine artifact: `/tmp/opencode/duck-skill-evals/instruction-opt-pass0-baseline.json`

## Scope (locked)

Included:
- `AGENTS.md`
- `agents/*/body.md`
- `agents/*/meta.json`
- `skills/duck-*/SKILL.md`

Excluded:
- `dist/**`
- `docs/**` (except this baseline + optimization plan)
- non-duck skills

## Baseline Totals

- File count: `22`
- Estimated tokens (total): `6579`
- Total lines: `1724`
- Total words: `8773`

### Token share by artifact type

| Type | Files | Estimated tokens | Share |
|---|---:|---:|---:|
| always-load-global (`AGENTS.md`) | 1 | 279 | 4.2% |
| always-load-router (`agents/rubber-duck/body.md`) | 1 | 669 | 10.2% |
| duckling-body (`agents/duck-*/body.md`) | 6 | 1607 | 24.4% |
| skills (`skills/duck-*/SKILL.md`) | 7 | 3703 | 56.3% |
| meta (`agents/*/meta.json`) | 7 | 321 | 4.9% |

Largest optimization pool is skills + router+ducklings (~90.9% combined).

## Top 10 Heaviest Files

| Path | Type | Est tokens |
|---|---|---:|
| `skills/duck-debug/SKILL.md` | skill | 776 |
| `skills/duck-design/SKILL.md` | skill | 676 |
| `agents/rubber-duck/body.md` | always-load-router | 669 |
| `skills/duck-triage/SKILL.md` | skill | 574 |
| `skills/duck-review/SKILL.md` | skill | 544 |
| `skills/duck-teach/SKILL.md` | skill | 476 |
| `skills/duck-debt/SKILL.md` | skill | 371 |
| `agents/duck-builder/body.md` | duckling-body | 356 |
| `agents/duck-reviewer/body.md` | duckling-body | 292 |
| `skills/duck-explain/SKILL.md` | skill | 286 |

## Duplication Markers (read-only)

- Safety carve-out phrase hits (`trust-boundary validation`): `12`
- Clarifying-question phrasing hits (`ask one ... clarifying question`): `10`
- `Inherit shared guardrails` hits: `7`
- `## Output Contract` heading hits: `8`
- `## Boundaries` heading hits: `14`

Interpretation:
- Shared policy repetition is a major compression target.
- Output/boundary sections are structurally duplicated across router/ducklings/skills.

## Overfit / Dead-End Signal Scan (read-only)

### Rigid rule signals (likely eval overfit pressure)

- `skills/duck-triage/SKILL.md`: `at least 3` deterministic test-line target
- `skills/duck-design/SKILL.md`: multiple `exactly one` + hard first-turn caps
- `skills/duck-debug/SKILL.md`: hard line/word ceilings
- `skills/duck-explain/SKILL.md`: hard max-word budget
- `skills/duck-debt/SKILL.md`: multiple `hard` rule sections

### Overlap/branch signals

- `agents/duck-reviewer/body.md` overlaps schema enforcement with `skills/duck-review/SKILL.md`
- Cross-duckling repeated boundary phrase (`no final PR thread formatting` family) appears in several ducklings
- Potential low-value branch repetition in ducklings where role-only variance is small relative to shared policy text

No critical unusable branches found in Pass 0; findings are optimization-oriented.

## Must-Preserve Invariants (verified present)

- Mutating approval gate present ✅
- Scope split rule for `>2 files` present ✅
- Safety carve-outs present ✅
- Skill-load hard contract present ✅
- Ordered checkpoint model present ✅

## Priority Candidates (P1/P2/P3)

### P1 — highest impact

1. `agents/rubber-duck/body.md` (route-order + contract dedupe)
2. `skills/duck-debug/SKILL.md`
3. `skills/duck-design/SKILL.md`
4. `skills/duck-triage/SKILL.md`

### P2 — medium impact

1. `skills/duck-review/SKILL.md`
2. `skills/duck-teach/SKILL.md`
3. `agents/duck-builder/body.md`
4. `agents/duck-reviewer/body.md`

### P3 — low impact/hygiene

1. `skills/duck-debt/SKILL.md`
2. `skills/duck-explain/SKILL.md`
3. `agents/*/meta.json`

## Pass 0 Exit Criteria

Completed:

1. Baseline metrics table captured ✅
2. Prioritized candidate list captured ✅
3. Must-preserve invariants checklist captured ✅

Next: begin Pass 1 (router + global dedupe) using this baseline as reference.
