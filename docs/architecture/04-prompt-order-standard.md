# Prompt Order Standard

Canonical section order for agent and skill prompt files. Goal: predictable precedence, less duplication drift.

## Why

- Early sections get stronger behavioral weight in practice.
- Safety/approval constraints should appear before method details.
- Action-oriented flow: principles → gates → workflow → output.

## Agent file order (recommended)

1. `## Role`
2. `## Core Principles` (decision ownership, evidence-first, duck ladder or similar guidance)
3. `## Safety Gates` (mutating action gate, safety carve-outs)
4. `## Workflow` (execution flow, clarify-first, mutating checkpoints)
5. `## Output Format` (terse/direct guidelines, approval ask requirements)

Optional sections (use only when adding value):
- `## Inputs` (for delegator agents like duckling)
- `## Boundaries` (hard constraints not covered in Safety Gates)

Removed from standard (merge into above):
- ~~Agent Contracts~~ → merge into Inputs or Workflow
- ~~When to Use~~ → not needed for agent bodies
- ~~Preflight Checks~~ → merge into Safety Gates or Workflow
- ~~Rules & Limits~~ → merge into Core Principles

## Skill file order (recommended)

1. `## Purpose`
2. `## Philosophy Guardrails (skill-local)`
3. `## Activation` (when to use this skill)
4. `## Method` (step-by-step execution, including output formats inline)
5. `## Boundaries` (hard constraints, handoffs)

Optional sections:
- `## References` / `## Examples` / `## Edge Cases` (as needed)

Removed from standard (merge into Method):
- ~~Output Format~~ → describe inline in Method steps (reduces duplication)
- ~~Preflight Checks~~ → merge into Method or Boundaries

## Compression rules

- Keep one canonical section per concern; remove duplicate repeated sections.
- Prefer short bullets over repeated prose.
- Preserve policy semantics when moving sections.
- Do not weaken:
  - explicit user approval requirements for mutating actions,
  - scope split rule for `>2` files,
  - trust-boundary/security/data-loss/accessibility/explicit requirement carve-outs.

## Section purpose guide

**Core Principles** (agents): Decision ownership baseline + evidence-first grounding + core guidance patterns (e.g., Duck Ladder). Front-loads philosophy before execution.

**Safety Gates** (agents): Mutating action gate (execution approval) + safety carve-outs. Consolidated safety concerns in one place.

**Workflow** (agents/skills): Execution flow. Action-first; moved up from old position #7. For agents: clarify-first, quack delegation, mutating checkpoints. For skills: numbered Method steps.

**Output Format** (agents): Terse/direct guidelines + approval ask requirements for mutating responses. Kept near end for agents (format is secondary to safety/workflow). For skills: merged inline into Method steps.

**Method** (skills): Step-by-step execution logic. Output formats described inline where relevant (e.g., "Step 3: emit heartbeat + quick-help"). Reduces duplication with separate Output Format section.
