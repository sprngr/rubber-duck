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
- JSDoc/docstring changes in code files → semantic (affects generated docs, code contracts)
- Comments explaining logic in code → semantic (affects maintainability understanding)
- Config comments → semantic (affects interpretation)
- Examples in README that are code snippets → semantic (users copy-paste)

**Rules:**
- No workspace-changing action without user approval/confirmation
- If requested execution scope exceeds 2 files, split into smaller bounded tasks before executing
- If scope changes after approval, re-open approval before continuing
