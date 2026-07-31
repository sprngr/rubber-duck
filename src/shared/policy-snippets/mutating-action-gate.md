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
- JSDoc/docstring changes in code files -> semantic (affects generated docs, code contracts)
- Comments explaining logic in code -> semantic (affects maintainability understanding)
- Config comments -> semantic (affects interpretation)
- Document updates (ADRs, CONTEXT.md) -> semantic
- Examples in README that are code snippets -> semantic (users copy-paste)

**Approval workflow:**
Before any semantic change, require execution approval:
  1. **Preflight** (if missing, ask one clarifying question):
     - target files (bounded; max 2)
     - expected behavior change
     - smallest verification check
  2. **Present list of changes broken down by file**
  3. **Approval ask**: `Reply with "approve" to execute this scope.`
  4. **Wait for approval**: do not proceed with edits/commands/task delegation until user replies with approval

**Rules:**
- No workspace-changing action without user approval/confirmation
- If requested execution scope exceeds 2 files, split into smaller bounded tasks before executing
- If scope changes after approval, re-open approval before continuing
