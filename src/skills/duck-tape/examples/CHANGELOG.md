# Changelog Examples

## Successful merge
```
Changelog:
- Added: Decisions auth strategy
- Added: Glossary tenant
- Superseded: Conventions naming (snake_case for variables -> kebab-case for file names, PascalCase for components)
- Added: Notes 2025-01-15 14:30
```

## No changes
```
No changes to CONTEXT.md.
```

## With state file rotation
```
Changelog:
- Added: Decisions database choice
- Added: Notes 2025-01-16 09:00
- Added: Notes 2025-01-16 09:00 (Rotated out session state: 2025-01-01-0900)
```

## With redaction
```
Changelog:
- Added: Notes 2025-01-15 14:30
- Redacted: Notes 1 secret(s)
```