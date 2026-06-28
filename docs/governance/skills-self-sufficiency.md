# Skills Self-Sufficiency Report

## Purpose

Ensure every Rubber Duck skill enforces core philosophy even when router/`AGENTS.md` context is absent.

## Required philosophy dimensions per skill

Each skill now includes explicit local guardrails for:

1. Decision ownership
2. Ask-before-act behavior
3. Evidence-first reasoning
4. Bounded approval/actions
5. Safety carve-outs

## Skills covered

- `skills/duck-debug/SKILL.md`
- `skills/duck-review/SKILL.md`
- `skills/duck-design/SKILL.md`
- `skills/duck-explain/SKILL.md`
- `skills/duck-teach/SKILL.md`
- `skills/duck-triage/SKILL.md`
- `skills/duck-debt/SKILL.md`

## Additional refactor notes

- Removed dependency language referencing `caveman` and `caveman-review`.
- Kept terse/no-fluff default communication policy.
- Embedded review-prefix baseline directly in `duck-review`.

## Result

Status: **Pass**

Skill contracts are self-sufficient for policy/governance intent and no longer require caveman-mode dependency text.
