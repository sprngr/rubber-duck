# Changelog Examples

## Successful merge
```
Changelog:
- Added: Decisions auth strategy
- Added: Glossary tenant
- Superseded: Conventions naming (snake_case for variables -> kebab-case for file names, PascalCase for components)
- Added: Session-Log 2025-01-15 14:30
- Added: Notes 2025-01-15 14:30
```

## No changes
```
No changes to CONTEXT.md.
```

## With rotation
```
Changelog:
- Added: Decisions database choice
- Added: Session-Log 2025-01-16 09:00
- Dropped: Session-Log 2025-01-01 10:00 (rotation cap)
```

## With redaction
```
Changelog:
- Added: Notes 2025-01-15 14:30
- Redacted: Notes 1 secret(s)
```

## Session-Log rotation note
```
Rotated out session state: 2025-01-01-0900
Rotated out: initial setup (2025-01-01)
```