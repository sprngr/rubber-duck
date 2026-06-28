# Progressive Disclosure Ordering Proposal

## Objective

Improve readability and policy adherence by reordering all agent and skill prompt documents to follow progressive disclosure:

1. Fast orientation first.
2. Safety/ownership constraints before method detail.
3. Execution mechanics after the user understands scope.
4. Examples and edge cases last.

This proposal is structure-first with light wording cleanup only (no behavioral policy expansion beyond existing intent).

## Why this matters for Rubber Duck

Prompt contracts are effectively runtime interfaces. Inconsistent section ordering increases interpretation drift and can weaken philosophy adherence under reduced context.

Progressive disclosure ordering strengthens:

- decision ownership visibility,
- safety boundary recall,
- predictable handoff behavior,
- reviewer audit speed.

---

## Canonical section templates

## Agent template (subagents + router)

Use this section order after YAML frontmatter:

1. **Role**
   - one-line identity and responsibility
2. **When to Use**
   - trigger conditions / routing intent
3. **Boundaries (Hard Constraints)**
   - what the agent must not do
4. **Ownership & Safety Guardrails**
   - user owns decisions, non-negotiable safeguards
5. **Workflow**
   - ordered method steps
6. **Output Contract**
   - required format, prefixes, totals, coverage fields
7. **Rules & Limits**
   - caps, dedupe, no-nit constraints
8. **Handoff**
   - explicit next-agent routing where relevant

### Light wording standard for agents

- Prefer short imperative bullets.
- Keep one concern per bullet.
- Put “ask clarifying question” language in Boundaries/Workflow, not scattered.
- Place safety carve-outs in one visible section (Ownership & Safety Guardrails).

---

## Skill template

Use this section order after YAML frontmatter:

1. **Purpose**
   - one-line job and user outcome
2. **Activation / When to Use**
   - input signals and routing intent
3. **Preflight Checks**
   - clarifying questions, assumptions, evidence requirements
4. **Method**
   - core procedure
5. **Output Format**
   - expected response structure
6. **Boundaries & Handoffs**
   - what skill does not do; where to route next
7. **Examples**
   - sample inputs/outputs
8. **Edge Cases**
   - uncertainty handling, missing context rules
9. **References** (optional)
   - linked guidance documents

### Light wording standard for skills

- Put all “ask before action” language in Preflight + Boundaries.
- Keep ladder/minimal-change notes close to Method.
- Keep examples below operational contract sections.
- Keep edge-case behavior explicit and short.

---

## File-by-file reorder plan

## Agents

### `agents/rubber-duck.agent.md`

Current: routing first, preflight second, boundaries third.

Proposed order:
1. Role
2. When to Use (Skill Context Routing)
3. Boundaries (Duckling boundaries)
4. Ownership & Safety Guardrails (soft preflight + ladder + carve-outs)
5. Workflow summary (review/debug/design flows)

Light cleanup:
- merge repeated flow references into one “Workflow summary” block.
- keep `quack` behavior in “When to Use”.

### `agents/duck-investigator.agent.md`

Current: focus/output before refusal/rules/handoff.

Proposed order:
1. Role
2. When to Use
3. Boundaries (read-only, no fixes)
4. Ownership & Safety Guardrails
5. Workflow (focus items)
6. Output Contract
7. Rules & Limits
8. Handoff

Light cleanup:
- move “If asked to fix” line into Boundaries.

### `agents/duck-reviewer.agent.md`

Current: workflow then output then rules.

Proposed order:
1. Role
2. When to Use
3. Boundaries
4. Ownership & Safety Guardrails
5. Workflow
6. Output Contract
7. Rules & Limits

Light cleanup:
- keep all no-approval/no-edit clauses in Boundaries (single location).

### `agents/duck-adversary.agent.md`

Current: focus/ignore/boundaries/output/rules.

Proposed order:
1. Role
2. When to Use
3. Boundaries
4. Ownership & Safety Guardrails
5. Workflow (focus + ignore as method constraints)
6. Output Contract
7. Rules & Limits

Light cleanup:
- fold “Ignore” into workflow constraints.

### `agents/duck-simple.agent.md`

Current: focus/heuristics/boundaries/output/rules.

Proposed order:
1. Role
2. When to Use
3. Boundaries
4. Ownership & Safety Guardrails
5. Workflow (focus + heuristics + interaction)
6. Output Contract
7. Rules & Limits

### `agents/duck-dry.agent.md`

Current: focus/do-not-flag/boundaries/output/rules.

Proposed order:
1. Role
2. When to Use
3. Boundaries
4. Ownership & Safety Guardrails
5. Workflow (focus + do-not-flag + interaction)
6. Output Contract
7. Rules & Limits

### `agents/duck-builder.agent.md`

Current: policy/scope/precondition/workflow/output/non-trivial/refuse.

Proposed order:
1. Role
2. When to Use
3. Boundaries
4. Ownership & Safety Guardrails
5. Preflight Checks (policy + scope + precondition)
6. Workflow
7. Output Contract
8. Rules & Limits (non-trivial logic rule + refusal conditions)

---

## Skills

### `skills/duck-debug/SKILL.md`

Current: methodology-heavy with worked example before boundaries.

Proposed order:
1. Purpose
2. Activation
3. Preflight Checks
4. Method (ladder + framework + tracing + assumptions + repro + stop)
5. Output Format (add short contract heading; currently implicit)
6. Boundaries & Handoffs
7. Worked Example
8. Edge Cases (if needed)

Light cleanup:
- keep “ask three before one answer” in Preflight.

### `skills/duck-review/SKILL.md`

Proposed order:
1. Purpose
2. Activation
3. Preflight Checks
4. Method (workflow + ladder)
5. Output Format + Prefixes
6. Boundaries & Handoffs
7. Examples
8. Edge Cases

### `skills/duck-design/SKILL.md`

Current: long workflow with references at end.

Proposed order:
1. Purpose
2. Activation
3. Preflight Checks
4. Method (clarify/chunk/assumptions/alternatives/matrix/pattern/confirm)
5. Output Format (compact template promoted here)
6. Boundaries & Handoffs
7. References

Light cleanup:
- move “compact template” from deep in method to Output Format section.

### `skills/duck-explain/SKILL.md`

Proposed order:
1. Purpose
2. Activation
3. Preflight Checks
4. Method
5. Output Format
6. Boundaries & Handoffs

Light cleanup:
- move current Output Format below Method only if preserving flow clarity; otherwise keep as #5.

### `skills/duck-teach/SKILL.md`

Proposed order:
1. Purpose
2. Activation
3. Preflight Checks
4. Method (tutorial structure + depth scaling + code conventions)
5. Output Format (derive from structure/depth)
6. Boundaries & Handoffs
7. Edge Cases (project-specific search vs generic)

### `skills/duck-triage/SKILL.md`

Proposed order:
1. Purpose
2. Activation
3. Preflight Checks
4. Method (coverage analysis + quality + edge discovery + severity + triage process)
5. Output Format (severity + rationale + test add)
6. Boundaries & Handoffs
7. Bug Report Format

### `skills/duck-debt/SKILL.md`

Proposed order:
1. Purpose
2. Activation
3. Preflight Checks
4. Method (marker convention + scan)
5. Output Format
6. Boundaries & Handoffs
7. Edge Cases (missing triggers/no markers)

---

## Rollout sequence (recommended)

1. Reorder router + all agents first (higher routing leverage).
2. Reorder high-traffic skills (`duck-review`, `duck-design`, `duck-debug`, `duck-triage`).
3. Reorder remaining skills.
4. Re-run governance rubric + behavior checks after each batch.

## Acceptance criteria for reorder pass

- No behavioral contract regression.
- All existing policy constraints preserved.
- Section ordering consistent with templates.
- Governance rerun remains pass.
