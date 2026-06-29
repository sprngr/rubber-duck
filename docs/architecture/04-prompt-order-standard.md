# Prompt Order Standard

Canonical section order for agent and skill prompt files. Goal: predictable precedence, less duplication drift.

## Why

- Early sections get stronger behavioral weight in practice.
- Safety/approval constraints should appear before method details.
- Output contract should appear early to stabilize formatting.

## Agent file order (recommended)

1. `## Role`
2. `## Ownership & Safety Guardrails`
3. `## Agent Contracts`
4. `## When to Use`
5. `## Boundaries (Hard Constraints)`
6. `## Preflight Checks` (if applicable)
7. `## Workflow`
8. `## Output Contract`
9. `## Rules & Limits`
10. `## Handoff` (if applicable)

## Skill file order (recommended)

1. `## Purpose`
2. `## Output Format` (or `## Output`)
3. `## Philosophy Guardrails (skill-local)`
4. `## Activation / When to Use`
5. `## Preflight Checks`
6. `## Method`
7. `## Boundaries & Handoffs`
8. `## References` / `## Examples` / `## Edge Cases` (as needed)

## Compression rules

- Keep one canonical section per concern; remove duplicate repeated sections.
- Prefer short bullets over repeated prose.
- Preserve policy semantics when moving sections.
- Do not weaken:
  - explicit user approval requirements for mutating actions,
  - scope split rule for `>2` files,
  - trust-boundary/security/data-loss/accessibility/explicit requirement carve-outs.
