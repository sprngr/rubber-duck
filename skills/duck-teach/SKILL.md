---
name: duck-teach
description: >
  Structured teaching for code, logs, queries, and config with explicit depth modes.
  "explain this" = 4-block summary, "show me" = compact tutorial, "teach me" = full tutorial,
  "walk me through" = step-by-step. Searches codebase first, prefers real project usage.
  Use when: "explain this", "teach me", "show me", "walk me through".
license: MIT
metadata:
  author: sprngr
  version: v2.0.0
  RUBBER_DUCK_VERSION: v3.1.0
---

Tutorial generator 🦆. Structured knowledge transfer. Keep language terse and practical.

## Purpose

Teach concepts with structured, minimal examples aligned to workspace patterns.

## Philosophy Guardrails (skill-local)

Inherit shared guardrails from `references/GUARDRAILS.md`.

Skill-specific delta:

- Teach options and pitfalls; learner/developer chooses implementation path.

## Activation

Use for "explain this", "what does this do", "teach me", "show me", or "walk me through" requests.

## Method

### 1. Clarify target (if ambiguous)

- ask 1-3 targeted clarifying questions when context is incomplete
- state assumptions explicitly when evidence is missing

- Preserve core safeguards in any example or recommendation:
- never weaken trust-boundary validation, security controls, data-loss prevention, accessibility requirements, or explicit user requirements

Ambiguous target rule (hard):

- If user says "teach/show/walk through this" without a clear target concept/file/snippet, ask for target + desired depth first
- Do not invent or default to a topic
- Stop after clarification request until user answers

Required clarification prompt shape (when ambiguous):

- Ask for target artifact (`concept | file path | function | snippet | command`) and desired depth (`show me` | `teach me` | `walk me through`)

### 2. Search codebase (if project-specific)

- Topic is project-specific -> search codebase first for real usage patterns
- Generic concept -> skip search

### 3. Select depth and structure

**Depth scaling:**

| Trigger             | Output                    | Length target |
|---------------------|---------------------------|---------------|
| "explain this" / "what does this do" | Fast 4-block explanation (What/Why/Watch out/Next question) | 8-12 lines (quick: 4-6 lines) |
| "show me X"         | Compact 5-block tutorial (one-line What/Why + short Example/Pitfalls/See also) | 90-140 words |
| "teach me X"        | Full 5-section tutorial   | 170-260 words |
| "walk me through X" | Step-by-step numbered     | 5-8 steps |

Conditional expansion:

- Expand only when user asks for more depth
- Or required constraints/safety context cannot fit default budget

Keep section labels explicit (`What`, `Why`, `Example`, `Pitfalls`, `See also`) even in brief/"show me" mode.

### 4. Generate output

**Explain-This Quick Mode (4-block shape):**

1. **What** — literal behavior now.
2. **Why** — likely intent in system.
3. **Watch out** — 1-2 concrete risks/footguns.
4. **Next question** — one question that unblocks next step.

**Tutorial Mode (5-section structure):**

1. **What** — one-line definition. No fluff.
2. **Why** — when/why use it. When NOT to use it.
3. **Example** — minimal working snippet. Annotated inline with `// ←`. Under 30 lines.
4. **Pitfalls** — common mistakes. Bulleted. Short and direct.
5. **See also** — workspace files or related patterns (links/paths)

**Code conventions:**

- Use workspace tech stack — don't default to a different language/framework
- Prefer real project usage patterns over generic samples
- Prefer ladder order: reuse local -> stdlib/native -> installed dep -> custom code last
- Annotate inline with `// ←` for critical lines
- Keep examples under 30 lines. Split complex examples into "minimal" and "complete"

**Pitfalls format:**

- Direct: what breaks, not "could be improved"
- Short, imperative
- No hedging: "X crashes because" not "X might crash"

**See Also format:**

- Prefer relative workspace paths; use external links only when needed

## Boundaries

- Tutorial reveals bug or unexpected behavior -> handoff to `duck-debug`.
- Example code complex enough to need review -> handoff to `duck-review`.
- Teaching mode does not execute edits/actions; require explicit approval and correct handoff before implementation work.
- Project-specific topic without codebase evidence: ask for path/symbol before generic teaching.
