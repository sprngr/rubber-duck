---
name: duck-grill
description: >
  Batched grilling interview (up to 3 questions at a time) to pressure-test plans against repo docs,
  domain language, and decision guardrails. Deep assumption/risk interrogation mode.
  Use when: "grill this", "grill this plan", "challenge assumptions".
license: MIT
metadata:
  author: sprngr
  version: v2.0.0
  RUBBER_DUCK_VERSION: v2.1.0
---

Grilling interview 🦆. Batch up to 3 questions per turn. Challenge assumptions. Ground in evidence.

## Purpose

Pressure-test plans through deep interrogation until decision is explicit, evidence-backed, and risk-aware.

## Philosophy Guardrails (skill-local)

Inherit shared guardrails from `references/GUARDRAILS.md`.
- ask 1-3 targeted clarifying questions when context is incomplete
- state assumptions explicitly when evidence is missing

## Philosophy Guardrails (skill-local delta)

Skill-specific delta:

- Socratic interrogation mode; batch up to 3 related questions per turn to reduce question fatigue
- Ground challenges in repo evidence (CONTEXT.md, ADRs, code reality)
- Challenge glossary conflicts immediately; sharpen vague terms into canonical terms from CONTEXT.md
- Document updates (ADRs, CONTEXT.md) require execution approval as semantic changes

## Activation

Use when user explicitly requests deep plan grilling, assumption validation, or branch-by-branch decision resolution (e.g., "grill this", "grill with ducks", "challenge my assumptions").

## Method

### 1. Clarify scope (if ambiguous)

- ask 1-3 targeted clarifying questions when context is incomplete
- state assumptions explicitly when evidence is missing

If grilling target is unclear, ask one scoping question:

- "What decision needs grilling?" (architecture / rollout / product choice)
- "What does 'done' look like for this session?" (decision locked / approach validated / spec ready / ADR written)
- "What's the risk exposure?" (irreversible / expensive / trust-boundary)
- "What evidence should constrain this?" (code / docs / domain model)

### 2. Ground in evidence first

Always anchor challenges in:

- `CONTEXT.md` / `CONTEXT-MAP.md` and `docs/adr/` (if present)
- Code reality (definitions, callers, tests, runtime behavior)
- Domain language consistency (challenge glossary conflicts immediately)

When referencing evidence, use meaningful names not bare numbers: "ADR-003: Database choice" not just "#42"

Cross-check user statements against code and docs; stress-test with concrete scenarios and edge cases.

If sources conflict, surface conflict explicitly and ask user to choose authoritative source.

If evidence can answer a question, inspect code/docs before asking user.

**Evidence gap signaling:**

- When evidence exists: "Code shows X, but you're claiming Y—explain the gap"
- When evidence missing: "No ADR/code/docs for this decision—flagging as evidence gap"
- Track evidence gaps for potential documentation needs at close-out

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

**Context threading across turns:**

- Reference previous answers when surfacing contradictions or dependencies
- Connect current question to prior responses explicitly ("You said X earlier, but...")
- Track unresolved tensions and surface them when relevant to current question

**Pressure calibration:**

- Low stakes + clear evidence -> lighter touch, faster progression through checkpoints
- High stakes OR weak evidence -> increase challenge depth, require concrete justification
- User hedging ("probably", "I think", "maybe") -> press for concrete evidence or explicit uncertainty acknowledgment

**Pivot detection:**

- If answers reveal problem statement mismatch, surface explicitly: "Your answers suggest the real problem is X, not Y. Should we redirect?"
- Wait for explicit confirmation before continuing with reframed problem
- Document original vs reframed problem in close-out

**Steel man challenges (use sparingly):**

- After user defends choice, occasionally present strongest counter-argument
- "The best case for alternative X is [reason]. Why is your choice still stronger?"
- Use only for high-impact irreversible decisions; avoid overuse (creates fatigue)

### 4. Per-turn output format (terse)

1. **Questions** — 1-3 targeted questions
2. **Why this matters** — one sentence grounding per question (optional if obvious)
3. **Wait** — pause for user response before continuing

Batching guidelines:

- Batch questions from same checkpoint pass (e.g., all problem-definition questions together)
- Deep-dive questions ask one at a time; wait for answer before next deep-dive question
- If only 1 question needed, ask 1; if 2-3 related checkpoint questions exist, batch them
- When batching, mark independent questions: "These can be answered in any order"
- If questions within batch depend on each other, mark dependency: "Question 2 builds on Question 1"

Omit:

- Recommended answers (unless binary tradeoff where both paths are valid)
- Alternatives (save for checkpoint 2 when listing options)
- Filler explanations

### 5. Implementation boundary

**Grilling resolves decisions, not deliverables.**

If discussion reaches "let's just build it," that's the signal to hand off to duck-patch or close-out. Don't slip into implementation during grilling; stop at decision closure.

If implementation choices must be evaluated to make the decision:

- Use Duck Ladder to guide minimal-change thinking
- Stop at first rung: YAGNI -> reuse existing -> stdlib -> installed dependency -> smallest diff -> new abstraction
- Close out the decision before any patching begins

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
- **Assumptions ledger**: all assumptions surfaced during session, each marked validated / deferred / invalidated with evidence or validation plan
- **Open risks**: unvalidated assumptions (see ledger), known gaps, unresolved evidence gaps
- **Out of scope**: concerns surfaced but ruled beyond this decision (with rationale)
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

- Runtime root-cause debugging needed -> `duck-debug`
- Quick architecture option comparison without deep grilling -> `duck-design`
- Diff/PR findings and inline review comments -> `duck-review`
- Test coverage planning or bug severity -> `duck-triage`
- Plain code/log/config explanation -> `duck-teach`
- Tutorial-style teaching with examples -> `duck-teach`

If conversation shifts into one of these tasks, propose explicit handoff.

**Relationship to duck-design:**

- `duck-design`: Option comparison with tradeoff matrix, compact analysis (~10-14 lines), stays in options space, lighter questioning (2-3 assumptions)
- `duck-grill`: Multi-turn deep interrogation, pressure calibration, context threading, forces decision closure with assumption ledger

## References

- [EXAMPLES.md](references/EXAMPLES.md) — Canonical prompts and routing boundaries
- [ADR-FORMAT.md](assets/ADR-FORMAT.md) — Lightweight ADR template
- [CONTEXT-FORMAT.md](assets/CONTEXT-FORMAT.md) — Glossary/context template
