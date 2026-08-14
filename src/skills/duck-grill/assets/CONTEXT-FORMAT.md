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

## Contents

- [Goals](#goals)
- [Decisions](#decisions)
- [Conventions](#conventions)
- [Glossary](#glossary)
- [Deferred-Debt](#deferred-debt)
- [Open-Questions](#open-questions)
- [Notes](#notes)

## Goals

- **[Goal Name]**: [what this project optimizes for]

## Decisions

- **[Decision Name]**: [decision summary] (date: [YYYY-MM-DD])

## Conventions

- **[Convention Name]**: [project-local convention/pattern]
- **System Map / [Component Name]**: [purpose, one sentence]
  - Location: `[path or service name]`
  - Depends on: [list]
  - Owned by: [team/person]
- **Boundary / Trust**: [where validation must occur]
- **Boundary / Data**: [where data ownership changes]
- **Boundary / Deployment**: [independently deployable units]

## Glossary

- **[Term]**: [One-sentence definition]
  - Code: `[canonical type/class name]`
  - Scope: [where this term applies]
  - Aliases: [other names used, if any]
  - Avoid: [terms to not use for this concept, if any]

## Deferred-Debt

- TODO([debt type]): [YYYY-MM-DD] [what deferred] [status: open|resolved]
- TODO([debt type],#<issue>): [YYYY-MM-DD] [what deferred] [resolved: decision summary]

## Open-Questions

- [question] (date: [YYYY-MM-DD])

## Notes

### [YYYY-MM-DD HH:MM]
[freeform context updates, constraints changes, session observations]
```

## Keep it current

Update CONTEXT.md when:

- A grilling/design session closes with a new or superseded decision
- Glossary terms, aliases, or avoid-terms change
- New deferred debt or open questions are identified
- Conventions/system boundaries change and must persist across sessions
- Before duck-tape merge, if schema sections are missing (run migrate first)

## Location

Canonical location: `CONTEXT.md` at project root.
