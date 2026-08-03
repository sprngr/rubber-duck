# Diff Format Examples

Reference for step 2 of the execution approval gate: "Present list of changes broken down by file as formatted diff."

## Format selection

- **File exists**: unified diff (`---`/`+++`/`@@` hunks, `-`/`+` prefixes). Same format as `git diff`.
- **File does not exist**: full content in fenced code block, file path as header.
- **One file per diff block**. File path as header before each block.

## Example 1: Edit to existing file

```markdown
`src/skills/duck-tape/hooks/extract-state.ps1`

\`\`\`diff
--- a/src/skills/duck-tape/hooks/extract-state.ps1
+++ b/src/skills/duck-tape/hooks/extract-state.ps1
@@ -159,7 +159,9 @@
     if ($obj.type -eq "user.message") {
-      if (-not $obj.data.content.StartsWith("<") -and [string]::IsNullOrEmpty($firstPrompt)) {
+      $content = $obj.data.content
+      if (-not [string]::IsNullOrEmpty($content) -and -not $content.StartsWith("<") -and [string]::IsNullOrEmpty($firstPrompt)) {
         $firstPrompt = $content
       }
     }
\`\`\`
```

## Example 2: New file

```markdown
`tests/fixtures/copilot-transcript.jsonl`

\`\`\`jsonl
{"type":"session.start","timestamp":"2026-08-01T00:00:00Z"}
{"type":"user.message","data":{"content":"Build the feature"},"timestamp":"2026-08-01T00:00:00Z"}
{"type":"user.message","data":{"content":null},"timestamp":"2026-08-01T00:00:00Z"}
{"type":"assistant.message","data":{"content":"Starting work","reasoningText":"thinking"},"timestamp":"2026-08-01T00:00:01Z"}
\`\`\`
```

## Example 3: Multi-file change (2 files, one edit + one new)

```markdown
`src/shared/policy-snippets/mutating-action-gate.md`

\`\`\`diff
--- a/src/shared/policy-snippets/mutating-action-gate.md
+++ b/src/shared/policy-snippets/mutating-action-gate.md
@@ -30,1 +30,4 @@
-  2. **Present list of changes broken down by file**
+  2. **Present list of changes broken down by file as formatted diff**
+     - File exists: unified diff (`---`/`+++`/`@@` hunks, `-`/`+` prefixes)
+     - File does not exist: full content in fenced code block, file path as header
+     - One file per diff block
\`\`\`

`src/shared/references/diff-format-examples.md`

\`\`\`markdown
# Diff Format Examples

Reference for step 2 of the execution approval gate...
\`\`\`
```

## Example 4: Cosmetic change (whitespace-only)

```markdown
`docs/architecture/03-adaptive-socratic-policy.md`

\`\`\`diff
--- a/docs/architecture/03-adaptive-socratic-policy.md
+++ b/docs/architecture/03-adaptive-socratic-policy.md
@@ -42,7 +42,7 @@
-The  duck  ladder  has  double  spaces.
+The duck ladder has single spaces.
\`\`\`
```
