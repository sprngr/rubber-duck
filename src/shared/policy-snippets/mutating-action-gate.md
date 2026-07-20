**Workspace-changing actions** (all require checkpoint-3 approval):
- File edits (code, docs, config, any text file)
- File creation, deletion, or moves
- Commands that modify workspace (git commit, install, build, deploy)
- Task delegation to subagents for implementation/patching

**Rules:**
- No workspace-changing action without explicit user approval on bounded scope
- If requested execution scope exceeds 2 files, split into smaller bounded tasks before executing
- If scope changes after approval, re-open scope confirmation before continuing
