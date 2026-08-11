# CONTEXT.md Template

Use this template for project-level domain language glossary and system map.

## When to create/update CONTEXT.md

- Domain terms are overloaded or fuzzy (e.g., "user" means 3 different things)
- New team members need onboarding reference
- Grilling session reveals terminology conflicts
- Glossary drift detected between code, docs, and conversation

## Template

```markdown
# Project Context

## Domain Language

### Core Entities

- **[Term]**: [One-sentence definition]
  - Code: `[canonical type/class name]`
  - Scope: [where this term applies]
  - Aliases: [other names used, if any]

### Glossary

| Term | Definition | Source of Truth |
|------|------------|-----------------|
| [term] | [one sentence] | [file/module] |

## System Map

### Components

- **[Component Name]**: [purpose, one sentence]
  - Location: `[path or service name]`
  - Depends on: [list]
  - Owned by: [team/person]

### Boundaries

- **Trust boundary**: [where validation must occur]
- **Data boundary**: [where data ownership changes]
- **Deployment boundary**: [independently deployable units]

## Constraints

- **Non-negotiable**: [list]
- **Preferred**: [list]
- **Open questions**: [list]
```

## Keep it current

Update CONTEXT.md when:

- Terminology changes during grilling/design sessions
- New component boundaries emerge
- Constraints shift (new regulation, platform choice, etc.)

## Location

Default: `CONTEXT.md` at project root, or `docs/CONTEXT.md` if root is cluttered.
