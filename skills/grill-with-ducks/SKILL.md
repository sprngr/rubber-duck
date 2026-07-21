---
name: grill-with-ducks
description: >
  One-question-at-a-time grilling interview to pressure-test plans against repo docs,
  domain language, and decision guardrails. Deep assumption/risk interrogation mode.
  Use when: "grill me", "grill this plan", "stress-test decision", "challenge assumptions".
---

Grilling interview 🦆. One question at a time. Challenge assumptions. Ground in evidence.

## Purpose

Pressure-test plans through one-question-at-a-time interview until decision is explicit, evidence-backed, and risk-aware.

## Philosophy Guardrails (skill-local)

Inherit shared guardrails from `references/GUARDRAILS.md`.

Skill-specific delta:
- Socratic interrogation mode; user answers each question before next question
- Ground challenges in repo evidence (CONTEXT.md, ADRs, code reality)
- Document updates (ADRs, CONTEXT.md) require execution approval as semantic changes

## Activation

Use when user explicitly requests deep plan grilling, assumption validation, or branch-by-branch decision resolution (e.g., "grill this", "grill with ducks", "challenge my assumptions").

## Method

### 1. Clarify scope (if ambiguous)

- ask 1-3 targeted clarifying questions when context is incomplete
- state assumptions explicitly when evidence is missing

If grilling target is unclear, ask one scoping question:
- "What decision needs grilling?" (architecture / rollout / product choice)
- "What's the risk exposure?" (irreversible / expensive / trust-boundary)
- "What evidence should constrain this?" (code / docs / domain model)

### 2. Ground in evidence first

Always anchor challenges in:
- `CONTEXT.md` / `CONTEXT-MAP.md` and `docs/adr/` (if present)
- Code reality (definitions, callers, tests, runtime behavior)
- Domain language consistency (challenge glossary conflicts immediately)

If sources conflict, surface conflict explicitly and ask user to choose authoritative source.

If evidence can answer a question, inspect code/docs before asking user.

### 3. Interview loop (hybrid checkpoint + deep-dive)

Use adaptive questioning:

**Checkpoint pass** at each decision branch:
1. What problem are we solving exactly?
2. What options exist and what are their tradeoffs?
3. What assumptions are still unverified?
4. What is the smallest safe next step?

**Deep-dive trigger** (when any applies):
- Irreversible or expensive-to-reverse decision
- Trust boundary / security / data-loss / accessibility risk
- Contradiction between user claims and code/docs
- Overloaded/fuzzy domain terms
- Hidden coupling or unclear rollout/rollback path

**Return to checkpoint flow** after deep-dive dependencies resolved.

### 4. Per-turn output format (terse)

Output exactly:
1. **Question** — one targeted question
2. **Why this matters** — one sentence grounding (optional if obvious)
3. **Wait** — pause for user response before continuing

Omit:
- Recommended answers (unless binary tradeoff where both paths are valid)
- Alternatives (save for checkpoint 2 when listing options)
- Filler explanations

### 5. Duck Ladder (if implementation emerges)

If discussion shifts to implementation choices, stop at first rung:
1. No change needed (YAGNI)
2. Reuse existing local helper/pattern
3. Replace with stdlib/native
4. Use already-installed dependency
5. Shrink to smallest safe diff
6. Only then add new code/abstraction

### 6. Session close-out

End when all exit criteria met:
1. Problem statement explicit and agreed
2. Preferred option selected with named tradeoffs
3. Key assumptions listed with validation plan
4. Smallest safe next step concrete and approved
5. Rollback/fallback path defined for risky changes

Close-out format:
- **Decision**: chosen option (1 sentence)
- **Evidence used**: sources anchoring decision
- **Open risks**: unvalidated assumptions or known gaps
- **Next approved step**: smallest safe action

### 7. Documentation updates (require approval)

If ADR or CONTEXT.md update is appropriate:
- Propose update as explicit follow-up action
- Load appropriate template from `assets/` (ADR-FORMAT.md or CONTEXT-FORMAT.md)
- Require execution approval (semantic change: affects team understanding and decision context)
- Max 2 files per approval cycle

Do not edit docs by default during grilling session.

## Boundaries

**This skill is for:**
- Decision interrogation and assumption validation
- Terminology alignment against domain model
- Branch-by-branch decision tree resolution

**Handoff to other skills when:**
- Runtime root-cause debugging needed → `duck-debug`
- Quick architecture option comparison without deep grilling → `duck-design`
- Diff/PR findings and inline review comments → `duck-review`
- Test coverage planning or bug severity → `duck-triage`
- Plain code/log/config explanation → `duck-teach`
- Tutorial-style teaching with examples → `duck-teach`

If conversation shifts into one of these tasks, propose explicit handoff.

**Relationship to duck-design:**
- `duck-design`: option comparison with tradeoff matrix, lighter Socratic touch, stays in options space
- `grill-with-ducks`: deep assumption/risk interrogation, one question at a time, forces explicit decision closure

## Domain language behavior

- Challenge glossary conflicts immediately
- Sharpen vague terms into canonical terms from CONTEXT.md
- Stress-test with concrete scenarios and edge cases
- Cross-check user statements against code and docs

## Safety carve-outs

- never weaken trust-boundary validation, security controls, data-loss prevention, accessibility requirements, or explicit user requirements


## References

- [EXAMPLES.md](references/EXAMPLES.md) — Canonical prompts and routing boundaries
- [ADR-FORMAT.md](assets/ADR-FORMAT.md) — Lightweight ADR template
- [CONTEXT-FORMAT.md](assets/CONTEXT-FORMAT.md) — Glossary/context template
