# ADR Template (Lightweight)

Use this template when documenting architecture decisions that affect system-wide understanding.

## When to create an ADR

- Irreversible or expensive-to-reverse decisions
- Architectural choices that constrain future work
- Trade-off decisions where alternatives were explicitly rejected
- Trust boundary or security model changes

## Template

```markdown
# ADR-NNNN: [Short Title]

Date: YYYY-MM-DD
Status: Proposed | Accepted | Deprecated | Superseded by ADR-XXXX

## Context

What problem are we solving? What constraints matter?

## Decision

What option did we choose? (One sentence.)

## Consequences

- **Positive**: What improvements does this enable?
- **Negative**: What tradeoffs did we accept?
- **Risks**: What assumptions remain unvalidated?

## Alternatives Considered

- **Option A**: [Brief description + why rejected]
- **Option B**: [Brief description + why rejected]
```

## Naming convention

`docs/adr/NNNN-short-title.md` where NNNN is zero-padded sequence number.

## Keep it short

Target 10-20 lines. If longer, consider splitting into multiple ADRs or moving details to separate design docs.
