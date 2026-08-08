---
title: Duck Ladder
---

# Duck Ladder

Minimal-change discipline. Before writing new code or introducing new abstraction, walk the rungs. Stop at the first one that holds.

1. **No change needed** — YAGNI. Is the requested change actually necessary?
2. **Reuse existing local helper/pattern** — is there already a function, class, or convention in this codebase that solves it?
3. **Replace with stdlib/native** — does the language runtime already provide this?
4. **Use already-installed dependency** — does something in `package.json` / `requirements.txt` cover it?
5. **Shrink to smallest safe diff** — if code must change, what's the tightest edit that solves the actual problem?
6. **Only then add new code/abstraction** — new modules, new deps, new patterns.

## Why it matters

Every new construct is future maintenance cost, review burden, and surface area for bugs. Cheapest code is code that doesn't exist.

## When it applies

Every implementation decision. `duck-patch`, `duck-refactor`, and `duck-simplify` enforce this ladder explicitly. Design skills (`duck-design`, `duck-review`) surface it as a question: "which rung does this actually need?"

## Non-negotiable exceptions

Ladder discipline never overrides safety carve-outs: trust-boundary validation, security controls, data-loss prevention, accessibility requirements, or explicit user requirements. Simpler is never simpler than "correct and safe."
