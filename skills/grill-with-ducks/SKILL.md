---
name: grill-with-ducks
description: Runs a one-question-at-a-time grilling interview to pressure-test plans against repo docs, domain language, and Rubber Duck decision guardrails. Use when stress-testing architecture/product decisions, resolving ambiguous decision branches, validating assumptions and rollback risk, or when the user asks to "grill with ducks".
---

## Purpose

Pressure-test plans through a one-question-at-a-time interview until the decision is explicit, evidence-backed, and risk-aware.

## Output Format

Per turn, output exactly:
1. **Question** — one targeted question
2. **Why this matters** — one sentence
3. **Recommended answer** — one concise default
4. **Alternative** — only when tradeoff is material
5. **Wait** — pause for user response before continuing

Session close-out format:
- Decision
- Evidence used
- Open risks
- Next approved step

## Philosophy Guardrails (skill-local)

- Human decision ownership: user approves framing, scope, implementation, acceptance
- Socratic collaboration: ask targeted questions, do not autopilot
- Evidence before action: anchor claims in repository evidence
- Minimal-change discipline: prefer smallest safe, root-cause-oriented next step
- Safety boundaries: never trade away security/validation/data-loss prevention/accessibility/explicit requirements

## Activation / When to Use

Use when the user wants deep plan grilling, branch-by-branch decision resolution, or explicit assumption/rollback validation (e.g., "grill with ducks").

## Preflight Checks

Always ground challenges in:
- `CONTEXT.md` / `CONTEXT-MAP.md` and `docs/adr/` (if present)
- the philosophy guardrails
- code reality (definitions, callers, tests, runtime behavior)

If sources conflict, surface the conflict explicitly and ask the user to choose.

## Method

Use a hybrid loop:
1. **Checkpoint pass** at each branch:
1. What problem are we solving exactly?
2. What options exist and what are their tradeoffs?
3. What assumptions are still unverified?
4. What is the smallest safe next step?
2. **Deep-dive only when triggered** by:
   - irreversible or expensive-to-reverse decisions
   - trust boundary / security / data-loss / accessibility risks
   - contradiction between user claims and code/docs
   - overloaded/fuzzy domain terms
   - hidden coupling or unclear rollout/rollback path
3. **Return to checkpoint flow** after branch dependencies are resolved.

If evidence can answer a question, inspect code/docs before asking.

## Boundaries & Handoffs

This skill is for decision interviews, terminology alignment, and branch resolution.

Do not use this skill as primary mode for:
- runtime root-cause debugging (`duck-debug`)
- quick architecture option comparison without deep grilling (`duck-design`)
- diff/PR findings and inline review comments (`duck-review`)
- test coverage planning or bug severity classification (`duck-triage`)
- plain code/log/config explanation (`duck-explain`)
- tutorial-style teaching with examples (`duck-teach`)

If conversation shifts into one of those tasks, propose explicit handoff.

Do not edit docs by default during grilling. Propose doc updates/ADRs as explicit follow-up actions the user can approve.

## Domain language behavior

- Challenge glossary conflicts immediately.
- Sharpen vague terms into canonical terms.
- Stress-test with concrete scenarios and edge cases.
- Cross-check user statements against code and docs.

## Exit Criteria

End the session when all are true:
1. Problem statement is explicit and agreed
2. Preferred option selected with named tradeoffs
3. Key assumptions listed with validation plan
4. Smallest safe next step is concrete and approved
5. Rollback or fallback path is defined for risky changes

## References

- [EXAMPLES.md](references/EXAMPLES.md) — canonical prompts and routing boundaries
- [ADR-FORMAT.md](assets/ADR-FORMAT.md) — lightweight ADR template and offer criteria
- [CONTEXT-FORMAT.md](assets/CONTEXT-FORMAT.md) — glossary/context template for terminology alignment
