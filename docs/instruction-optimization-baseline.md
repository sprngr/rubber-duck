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

---

## Pass 1 Execution Log (router + global dedupe)

Status: completed

Files changed:
- `agents/rubber-duck/body.md`
- `AGENTS.md`

What changed:
- moved `When to Use` earlier in router body
- removed duplicate terminal `Output Contract` block in router
- tightened wording in mutating-scope language (no policy change)
- added explicit shared-pointer wording to global/router safety text

Estimated token delta (scoped files):

| File | Before | After | Delta |
|---|---:|---:|---:|
| `agents/rubber-duck/body.md` | 669 | 637 | -32 |
| `AGENTS.md` | 279 | 279 | 0 |
| **Net** | 948 | 916 | **-32** |

Invariant checks after Pass 1:
- skill-load hard requirement present ✅
- explicit user approval gate present ✅
- scope `>2 files` split rule present ✅
- ordered checkpoints present (`problem framing → solution selection → execution scope → acceptance`) ✅

Next:
- Pass 2 (duckling normalization), starting with:
  1) `agents/duck-reviewer/body.md`
  2) `agents/duck-builder/body.md`

---

## Pass 2 Execution Log (duckling normalization)

Status: completed

Files changed:
- `agents/duck-reviewer/body.md`
- `agents/duck-builder/body.md`
- `agents/duck-investigator/body.md`
- `agents/duck-adversary/body.md`
- `agents/duck-simple/body.md`
- `agents/duck-dry/body.md`

What changed:
- compressed repeated ownership/safety prose and replaced long repeated carve-out phrasing with shared-pointer wording (`AGENTS.md`)
- removed standalone repeated hard-boundary headings where content duplicated nearby sections
- preserved role-specific workflow focus and output-contract schemas
- retained boundary constraints (no edits outside role, no cross-lens ownership drift)

Estimated token delta (duckling bodies):

| File | Before | After | Delta |
|---|---:|---:|---:|
| `agents/duck-reviewer/body.md` | 292 | 258 | -34 |
| `agents/duck-builder/body.md` | 356 | 350 | -6 |
| `agents/duck-investigator/body.md` | 231 | 225 | -6 |
| `agents/duck-adversary/body.md` | 225 | 224 | -1 |
| `agents/duck-simple/body.md` | 247 | 232 | -15 |
| `agents/duck-dry/body.md` | 256 | 242 | -14 |
| **Net** | 1607 | 1531 | **-76** |

Safety/boundary checks after Pass 2:
- all six ducklings still include shared safety pointer/phrase ✅
- output-contract sections preserved across all six ✅
- role boundary constraints preserved (lens separation intact) ✅

Cumulative total after Pass 1 + Pass 2:
- Pass 1 net: `-32`
- Pass 2 net: `-76`
- **Cumulative net: `-108` estimated tokens**

Next:
- Pass 3 (skill anti-overfit softening), start with:
  1) `skills/duck-triage/SKILL.md`
  2) `skills/duck-explain/SKILL.md`

---

## Pass 3 Execution Log (skills, wave 1)

Status: in progress (wave 1 completed)

Files changed (wave 1):
- `skills/duck-triage/SKILL.md`
- `skills/duck-explain/SKILL.md`

What changed:
- `duck-triage`: softened rigid output minimum phrasing from hard count framing to default range framing while preserving deterministic `needs test:` / `missing evidence:` markers
- `duck-explain`: softened strict budget wording (`max` → `target`) to reduce overfit rigidity without changing 4-block structure

Estimated token delta (wave 1):

| File | Before | After | Delta |
|---|---:|---:|---:|
| `skills/duck-triage/SKILL.md` | 574 | 567 | -7 |
| `skills/duck-explain/SKILL.md` | 286 | 286 | 0 |
| **Net (wave 1)** | 860 | 853 | **-7** |

Cumulative total after Pass 1 + Pass 2 + Pass 3 wave 1:
- Pass 1 net: `-32`
- Pass 2 net: `-76`
- Pass 3 wave 1 net: `-7`
- **Cumulative net: `-115` estimated tokens**

Next (Pass 3 wave 2):
- `skills/duck-teach/SKILL.md`
- `skills/duck-review/SKILL.md`

## Pass 3 Execution Log (skills, wave 2)

Status: completed

Files changed (wave 2):
- `skills/duck-teach/SKILL.md`
- `skills/duck-review/SKILL.md`
- `skills/duck-debt/SKILL.md`

What changed:
- `duck-teach`: softened rigid phrasing (`under`/`exactly`) and trimmed repetitive formatting wording while preserving structure + ambiguity checks
- `duck-review`: removed heavy regex schema-hint line while preserving schema rules and self-check requirements
- `duck-debt`: consolidated default/recommended wording to avoid duplication; semantics preserved

Estimated token delta (wave 2):

| File | Before | After | Delta |
|---|---:|---:|---:|
| `skills/duck-teach/SKILL.md` | 476 | 464 | -12 |
| `skills/duck-review/SKILL.md` | 544 | 531 | -13 |
| `skills/duck-debt/SKILL.md` | 371 | 371 | 0 |
| **Net (wave 2)** | 1391 | 1366 | **-25** |

Pass 3 aggregate (wave 1 + wave 2):
- wave 1 net: `-7`
- wave 2 net: `-25`
- **Pass 3 net: `-32`**

Cumulative total after Pass 1 + Pass 2 + Pass 3:
- Pass 1 net: `-32`
- Pass 2 net: `-76`
- Pass 3 net: `-32`
- **Cumulative net: `-140` estimated tokens**

Next:
- optional Pass 3b candidates: `skills/duck-debug/SKILL.md`, `skills/duck-design/SKILL.md`
- then run mini evals before a full rerun

## Pass 3 Execution Log (skills, wave 3 / optional 3b)

Status: completed

Files changed (wave 3):
- `skills/duck-debug/SKILL.md`
- `skills/duck-design/SKILL.md`

What changed:
- `duck-debug`: softened budget wording and removed long worked example block to keep core method/rules always-loaded while preserving ask-first, ladder, and handoff rules
- `duck-design`: softened rigid budget wording and trimmed duplicated phrasing while preserving tradeoff workflow and handoffs

Estimated token delta (wave 3):

| File | Before | After | Delta |
|---|---:|---:|---:|
| `skills/duck-debug/SKILL.md` | 776 | 664 | -112 |
| `skills/duck-design/SKILL.md` | 676 | 667 | -9 |
| **Net (wave 3)** | 1452 | 1331 | **-121** |

Pass 3 aggregate (wave 1 + wave 2 + wave 3):
- wave 1 net: `-7`
- wave 2 net: `-25`
- wave 3 net: `-121`
- **Pass 3 net: `-153`**

Cumulative total after Pass 1 + Pass 2 + Pass 3:
- Pass 1 net: `-32`
- Pass 2 net: `-76`
- Pass 3 net: `-153`
- **Cumulative net: `-261` estimated tokens**

Quick invariants check (wave 3):
- `duck-debug`: ask-first cadence + Duck Ladder + triage/design redirects present ✅
- `duck-design`: Duck Ladder + tradeoff flow + debug/triage redirects present ✅

Next:
- run mini evals on touched skills before full rerun (`duck-debug`, `duck-design`, plus earlier pass-3 skills as needed)
