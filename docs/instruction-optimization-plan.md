# Instruction Optimization Plan (Router, Ducklings, Skills)

Status: draft baseline plan
Date: 2026-07-04
Scope: repo-local instruction artifacts only (`AGENTS.md`, `agents/**`, `skills/duck-*/SKILL.md`, agent `meta.json`)

## Goal

Reduce always-loaded instruction/token cost by **15–25%** without changing behavior contracts, safety boundaries, or eval stability.

## Non-Negotiables

Do not weaken/remove:

- mutating approval gate
- trust-boundary/security/data-loss/accessibility protections
- explicit user requirement preservation
- duckling role boundaries
- required skill-load contract for routed tasks

## Baseline Snapshot (Pass 0)

Create and keep a before/after benchmark for estimated tokens and structure.

Required baseline outputs:
- estimated token table by file
- total estimated tokens for audited set
- role classification per file:
  - hot path always-load (`agents/rubber-duck/body.md`, `AGENTS.md`)
  - route-loaded skills (`skills/duck-*/SKILL.md`)
  - subagent-loaded ducklings (`agents/duck-*/body.md`)
  - metadata payloads (`agents/*/meta.json`)

## Execution Passes

### Pass 1 — Router + Global Dedupe (highest ROI, safest)

Primary targets:
- `agents/rubber-duck/body.md`
- `AGENTS.md` (only if wording pointers need alignment)

Actions:
- move route map (`When to Use`) earlier in router body
- remove duplicate contract/output sections where semantically redundant
- replace repeated long safety prose with pointer to shared guardrails
- preserve hard gate requirements and checkpoint order

Expected savings:
- ~120–220 estimated tokens

Verification:
- route smoke checks across review/debug/explain/teach/design/triage
- ensure mutating-action gate still enforced

### Pass 2 — Duckling Body Normalization

Priority order:
1. `agents/duck-reviewer/body.md`
2. `agents/duck-builder/body.md`
3. `agents/duck-investigator/body.md`
4. `agents/duck-adversary/body.md`
5. `agents/duck-simple/body.md`
6. `agents/duck-dry/body.md`

Actions:
- preserve role-specific boundaries and output schemas
- compress repeated ownership/safety/ambiguity language
- keep one shared phrasing pattern where possible
- avoid duplicating `duck-review` schema enforcement in both reviewer+skill unless strictly needed

Expected savings:
- ~250–450 estimated tokens total

Verification:
- run relevant validation prompts from `docs/validation/`
- confirm no dead-end branches introduced

### Pass 3 — Skill Anti-Overfit Softening

Priority order:
1. `skills/duck-triage/SKILL.md`
2. `skills/duck-explain/SKILL.md`
3. `skills/duck-teach/SKILL.md`
4. `skills/duck-review/SKILL.md`
5. `skills/duck-debt/SKILL.md`

Actions:
- keep deterministic behavior where evals require it
- soften rigid numeric constraints where not required (use defaults/ranges)
- move heavy examples/schema hints to references when safe
- retain explicit safety and handoff boundaries

Expected savings:
- ~350–650 estimated tokens total

Verification:
- mini evals for touched skills first
- one full normalized run after grouped changes

### Pass 4 — Metadata Payload Trim

Targets:
- `agents/*/meta.json`

Actions:
- tighten descriptions while preserving routing distinction
- remove unused/duplicative tool declarations only when confirmed safe

Expected savings:
- ~20–60 estimated tokens

Verification:
- sanity-check harness behavior and tool availability assumptions

## Reporting Contract Per Pass

For each pass, record:

1. files changed
2. before/after estimated tokens by changed file
3. total estimated token delta
4. behavior invariants checklist (hard gates/safety/boundaries)
5. validation/eval result summary

## Initial Sequence

Recommended run order:

1. Pass 1 now (router/global)
2. Pass 2 on reviewer + builder first
3. Pass 3 on triage/explain/teach
4. full eval rerun
5. Pass 3b on review/debt if needed
6. Pass 4 metadata cleanup

## Working Notes

- Use bounded edits per step and reopen scope confirmation if scope shifts.
- Keep this document as the single reference plan during execution.
