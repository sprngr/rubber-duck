**Workspace-changing actions** (require approval based on change type):

**Semantic changes** (require full execution approval):
- Code/logic changes
- Config/schema changes (settings, env vars, build config)
- Dependency changes (package.json, requirements.txt, etc.)
- File operations (create, delete, move)
- Mutating commands (git commit, install, build, deploy)
- Task delegation for implementation/patching

**Cosmetic changes** (require lightweight confirmation):
- Documentation edits (README, markdown files, standalone doc comments)
- Formatting/whitespace-only changes
- Typo fixes in non-code text files
- Confirmation phrase: "Confirm to proceed with [doc/formatting] change?"

**Edge cases:**
- JSDoc/docstring changes in code files are semantic (affects generated docs, code contracts)
- Comments explaining logic in code are semantic (affects maintainability understanding)
- Config comments are semantic (affects interpretation)
- Document updates (ADRs, CONTEXT.md) are semantic
- Examples in README that are code snippets are semantic (users copy-paste)

**Approval workflow:**
Before any semantic change, require execution approval:
  1. **Preflight** (if missing, ask one clarifying question):
     - target phase:
       - Phase 1: stubs/interfaces
       - Phase 2: wiring/integration
       - Phase 3: concrete implementation
     - target files (bounded for selected phase)
     - expected behavior change
     - smallest verification check
  2. **Present list of changes broken down by file as formatted diff**
     - File exists: unified diff (`---`/`+++`/`@@` hunks, `-`/`+` prefixes)
     - File does not exist: full content in fenced code block, file path as header
     - One file per diff block
  3. **Approval ask**: `Reply with approval intent to execute this scope (ex: "approve", "ok", "confirm").`
  4. **Wait for approval**: do not proceed with edits/commands/task delegation until user replies with explicit approval intent

**Rules:**
- No workspace-changing action without user approval/confirmation
- Treat explicit approval intent as approval: "approve", "approved", "ok", "go ahead", "confirm"
- Phase caps (default):
  - Phase 1 (stubs/interfaces): up to 6 files
  - Phase 2 (wiring/integration): up to 4 files
  - Phase 3 (concrete implementation): up to 2 files
- If a phase exceeds its cap, split into smaller bounded approvals before executing.
- Review-fatigue triggers (objective):
  - Phase 1 (stubs/interfaces):
    - If proposed diff in one approval exceeds 180 changed lines (additions + deletions) total, reduce current phase cap by at least 1 file.
    - If any single file exceeds 90 changed lines (additions + deletions), split that file into a separate approval or smaller sequential edits.
  - Phase 2 (wiring/integration):
    - If proposed diff in one approval exceeds 120 changed lines (additions + deletions) total, reduce current phase cap by at least 1 file.
    - If any single file exceeds 60 changed lines (additions + deletions), split that file into a separate approval or smaller sequential edits.
  - Phase 3 (concrete implementation):
    - If proposed diff in one approval exceeds 80 changed lines (additions + deletions) total, reduce current phase cap by at least 1 file.
    - If any single file exceeds 40 changed lines (additions + deletions), split that file into a separate approval or smaller sequential edits.
  - If reviewer requests clarification on more than 2 files in same batch, reduce next batch by at least 1 file.
- If complexity or review fatigue increases, reduce cap further and continue in smaller batches.
- Reopen execution approval between phases, even when objective stays same.
- If scope changes after approval, re-open approval before continuing
