# ADR Format

ADRs live in `docs/adr/` and use sequential numbering: `0001-slug.md`, `0002-slug.md`, etc.

Create `docs/adr/` lazily — only when the first ADR is approved.

## Template

```md
# {Short title of the decision}

{1-3 sentences: context, decision, and why.}
```

Keep ADRs lightweight. The value is recording *what was decided* and *why*, not filling a long template.

## Optional sections

Only include when they add real value:

- **Status** frontmatter (`proposed | accepted | deprecated | superseded by ADR-NNNN`)
- **Considered Options** (when rejected alternatives are worth preserving)
- **Consequences** (when non-obvious downstream effects matter)

## Numbering

Scan `docs/adr/` for the highest existing number and increment by one.

## When to offer an ADR

All three must be true:

1. **Hard to reverse** — changing later is meaningfully costly
2. **Surprising without context** — future reader would ask "why this way?"
3. **Real trade-off** — genuine alternatives existed and were evaluated

If any one is missing, skip ADR and keep moving.

### What qualifies

- **Architectural shape.** Monorepo vs polyrepo, event-sourced write model, projection strategy
- **Inter-context integration pattern.** Events vs synchronous calls
- **Lock-in choices.** Database, message bus, auth provider, deployment substrate
- **Boundary/scope decisions.** Which context owns which data and responsibilities
- **Deliberate non-obvious deviations.** Manual SQL over ORM, explicit constraints over defaults
- **External constraints not visible in code.** Compliance, contractual latency budgets, platform constraints
- **Rejected alternatives worth remembering.** Non-obvious "no" decisions likely to reappear
