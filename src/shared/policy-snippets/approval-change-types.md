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
