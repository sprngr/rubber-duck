# Baseline Rubric Run — 2026-06-28

## Review metadata

- Reviewer: rubber-duck (policy audit pass)
- Date: 2026-06-28
- Scope: all agents + all skills
- Method: prompt-contract review (static), using `docs/governance/rubric.md`

## Scores

Scale: 0 absent, 1 partial, 2 explicit/enforceable

| Artifact | R1 | R2 | R3 | R4 | R5 | R6 | Total | Threshold | Pass? |
|---|---:|---:|---:|---:|---:|---:|---:|---|---|
| agents/rubber-duck.agent.md | 2 | 2 | 2 | 2 | 1 | 1 | 10 | 12/12 | ❌ |
| agents/duck-investigator.agent.md | 1 | 1 | 2 | 2 | 1 | 0 | 7 | >=10/12, no 0 | ❌ |
| agents/duck-reviewer.agent.md | 1 | 1 | 1 | 2 | 2 | 1 | 8 | >=10/12, no 0 | ❌ |
| agents/duck-adversary.agent.md | 1 | 1 | 1 | 2 | 1 | 2 | 8 | >=10/12, no 0 | ❌ |
| agents/duck-simple.agent.md | 1 | 1 | 0 | 2 | 2 | 1 | 7 | >=10/12, no 0 | ❌ |
| agents/duck-dry.agent.md | 1 | 1 | 1 | 2 | 1 | 1 | 7 | >=10/12, no 0 | ❌ |
| agents/duck-builder.agent.md | 1 | 1 | 2 | 2 | 2 | 2 | 10 | >=10/12, no 0 | ✅ |
| skills/duck-debug/SKILL.md | 2 | 2 | 2 | 1 | 2 | 1 | 10 | >=10/12, no 0 | ✅ |
| skills/duck-review/SKILL.md | 1 | 1 | 1 | 2 | 2 | 2 | 9 | >=10/12, no 0 | ❌ |
| skills/duck-design/SKILL.md | 2 | 2 | 1 | 1 | 2 | 1 | 9 | >=10/12, no 0 | ❌ |
| skills/duck-explain/SKILL.md | 1 | 1 | 1 | 1 | 1 | 0 | 5 | >=10/12, no 0 | ❌ |
| skills/duck-teach/SKILL.md | 1 | 0 | 1 | 1 | 2 | 0 | 5 | >=10/12, no 0 | ❌ |
| skills/duck-triage/SKILL.md | 1 | 0 | 1 | 1 | 2 | 2 | 7 | >=10/12, no 0 | ❌ |
| skills/duck-debt/SKILL.md | 1 | 0 | 2 | 2 | 1 | 1 | 7 | >=10/12, no 0 | ❌ |

## Overall verdict

- Result: **Blocked**
- Router threshold unmet (10/12 vs required 12/12).
- Multiple non-router artifacts below 10 and/or include criterion 0.

## Evidence highlights

### Router

- Strong on Socratic + evidence-first routing:
  - `agents/rubber-duck.agent.md:22` investigator-first debug chain.
  - `agents/rubber-duck.agent.md:27` clarifying question for unrecognized input.
- Gaps against strict rubric:
  - Minimal-change ladder not explicit in router file.
  - Safety carve-outs not explicit in router file.

### Common cross-artifact gaps

1. **R6 safety carve-outs missing/implicit** in several agents/skills.
2. **R2 clarifying behavior not explicit** in some skills (`duck-teach`, `duck-triage`, `duck-debt`).
3. **R3 evidence-first phrasing inconsistent** outside investigator/debug paths.

## Priority remediation plan (from rubric findings)

1. Update router to explicitly encode minimal-change ladder + safety carve-outs.
2. Add explicit clarifying-question and assumption requirements to `duck-teach`, `duck-triage`, `duck-debt`.
3. Add evidence-first requirement lines to reviewer/simple/dry/explain/design where currently implicit.
4. Re-run rubric after prompt updates.
