# Execution Approval Gate Pattern

Complete specification for execution approval gates in rubber-duck skills.

---

## Purpose

Execution approval gate is a blocking checkpoint before any workspace-changing action (edits, commands, task delegation, commits).

Ensures user explicitly approves scope, expected behavior, and verification before assistant proceeds.

---

## Mutating Actions (Require Approval Gate)

**Code changes:**
- File edits (any text modification)
- File creation
- File deletion
- File moves/renames

**Commands:**
- git commit, git push
- npm install, pip install
- Database migrations
- Build commands that modify output
- Deploy commands

**Task delegation:**
- Delegating implementation work to subagent/skill
- Any action that results in workspace changes

**Non-mutating actions (No approval gate needed):**
- File reading
- Code analysis
- grep/search
- git status, git diff, git log
- Test runs that don't modify files
- Explanations, reviews, design discussions

---

## The 6-Step Blocking Workflow

### Step 1: Preflight (Gather Required Context)

If any of these items is missing, ask ONE clarifying question and STOP:

**Required preflight items:**
1. **Target files** — Bounded list (max 2 for patch, max 5 for refactor)
2. **Expected behavior change** — One-sentence description of what will work differently
3. **Smallest verification check** — How to confirm the change works (command, test, manual check)

**Example preflight:**
```markdown
**Preflight:**
- Target files: `src/auth.js`, `src/middleware/auth.js`
- Expected behavior: Login will validate token expiry and reject expired tokens
- Verification: Run `npm test -- auth.test.js` and confirm token-expiry test passes
```

**If incomplete, ask:**
- Missing files: "Which file(s) should I modify?"
- Missing behavior: "What should change in the application behavior?"
- Missing verification: "How should I verify the fix works?"

**Then STOP. Wait for user response before proceeding.**

---

### Step 2: Present List of Changes

Before asking for approval, present the specific changes broken down by file:

```markdown
**Changes:**
- `src/auth.js`: Add token expiry validation (lines 42-48)
- `src/middleware/auth.js`: Update auth check to use new validation
```

**Requirements:**
- List each file with brief description of what changes
- Show enough detail for user to scope the change before approving
- Keep to one line per file

---

### Step 3: Approval Ask (Exact Phrase Required)

Use this exact phrase:

```
Reply with "approve" to execute this scope.
```

**Variations NOT allowed:**
- ❌ "Proceed?"
- ❌ "Ready to execute?"
- ❌ "Should I continue?"
- ❌ "Type 'yes' to proceed"

**Must be:** ✅ `Reply with "approve" to execute this scope.`

---

### Step 4: Wait for Approval (Blocking Gate)

**Do NOT proceed to step 4 until user replies with "approve".**

**Accepted approval tokens:**
- ✅ "approve"
- ✅ "approved"
- ✅ "Approve"

**NOT accepted as approval:**
- ❌ "continue"
- ❌ "go ahead"
- ❌ "yes"
- ❌ "ok"
- ❌ "B" (from multi-choice)
- ❌ Any other continuation signal

**If user provides non-approval response:**
- Treat as scope clarification or question
- Re-gather preflight if scope changed
- Return to step 2 after clarification

**Blocking behavior:**
- Assistant must explicitly check for "approve" token
- No execution on implicit continuation
- No "I'll interpret 'yes' as approval"

---

### Step 5: Execute (Only After Approval Received)

Proceed with the approved scope:
1. Apply changes to approved files only
2. Make expected behavior change
3. Preserve existing patterns and style
4. Apply Duck Ladder discipline (minimal safe diff)

**During execution:**
- Do NOT broaden scope
- Do NOT touch additional files not in preflight
- Do NOT change behavior beyond what was approved

---

### Step 6: Verify (Run Smallest Check)

Run the agreed verification check:
- Execute test command
- Run manual verification steps
- Check output/logs
- Confirm expected behavior

**Report result:**
- ✅ Pass: "Verification passed: [evidence]"
- ❌ Fail: "Verification failed: [error] — Rollback? Or investigate?"

---

### Step 7: Scope-Change Detection (Re-Approval Trigger)

**If scope changes during or after execution, return to step 1:**

**Scope changes include:**
- Need to touch additional files not in preflight
- Behavior change broader than expected
- New requirement discovered during execution
- Verification revealed additional issues requiring fixes

**When scope changes:**
1. Stop current execution
2. Present new scope (files + behavior + verification)
3. Return to step 3 (approval ask)
4. Wait for new approval before continuing

---

## Template for Skills

Use this template when adding approval gate to skill Method section:

```markdown
### [Step N]: Execution approval

**Preflight** (if any item missing, ask one clarifying question and stop):
- Target files: [bounded list, max 2]
- Expected behavior change: [one-sentence description]
- Smallest verification check: [command or manual steps]

**Present list of changes:**
- `[file A]`: [change description]
- `[file B]`: [change description]

**Approval ask:**
Reply with "approve" to execute this scope.

**Wait for approval.** Do not proceed until user replies with "approve".

### [Step N+1]: Execute

[Only after approval received]

1. [execution steps]
2. Apply minimal safe diff
3. Preserve existing patterns
4. Run verification check
5. Report results

**If scope changes during execution:**
Return to preflight with new scope and request renewed approval.
```

---

## Two-Tier Approval (Semantic vs Cosmetic)

### Semantic Changes (Full 6-Step Approval)

**What qualifies as semantic:**
- Code/logic changes
- Config/schema changes (settings, env vars, build config)
- Dependency changes (package.json, requirements.txt)
- File operations (create, delete, move)
- Mutating commands (git commit, install, build, deploy)
- Task delegation for implementation

**Approval flow:** Full 6-step blocking workflow (preflight -> approve -> execute)

### Cosmetic Changes (Lightweight Confirmation)

**What qualifies as cosmetic:**
- Documentation edits (README, markdown files, standalone doc comments)
- Formatting/whitespace-only changes
- Typo fixes in non-code text files

**Approval flow:** Lightweight confirmation
- Present change briefly
- Ask: "Confirm to proceed with [doc/formatting] change?"
- Acceptable confirmations: "yes", "confirm", "ok", "go ahead", "approve"

**Edge cases (count as SEMANTIC, not cosmetic):**
- JSDoc/docstrings in code files -> semantic (affects generated docs)
- Comments explaining logic -> semantic (affects maintainability)
- Config comments -> semantic (affects interpretation)
- Code examples in README -> semantic (users copy-paste)

---

## Scope Limit Rules

**For patch-type skills:**
- Max 2 files per approval
- If scope requires >2 files, split into bounded tasks
- Request approval per task

**For refactor-type skills:**
- Max 5 files per approval
- If scope requires >5 files, split into bounded tasks
- Request approval per task

**Rationale:**
- Bounded scope reduces blast radius
- Easier to review and verify
- Clearer rollback path
- Forces minimal-change discipline

---

## Refusal Rules

**When to refuse execution:**

**"Run whatever commands and fix it"**
- Refuse silent execution
- Restate bounded-approval requirements
- Ask for specific scope (files + behavior + verification)

**Safety carve-out violations:**
- Refuse to weaken trust-boundary validation
- Refuse to bypass security controls
- Refuse to skip data-loss prevention
- Refuse to remove accessibility requirements
- Refuse to ignore explicit user requirements

**Provide rationale:**
"This change would [weaken security / bypass validation / remove safety check].
I can suggest a safer alternative: [alternative approach]."

---

## Anti-Patterns to Avoid

**❌ Implicit approval:**
```
User: "continue"
Assistant: *proceeds with execution*
```
**Why wrong:** "continue" is not "approve" — could mean "continue the conversation"

**❌ Skipping preflight:**
```
Assistant: "I'll fix the auth bug. Approve?"
User: "approve"
Assistant: *edits 5 files*
```
**Why wrong:** User didn't see files/behavior/verification before approving

**❌ Scope creep:**
```
[User approved 2 files]
Assistant: *edits those 2 files + discovers 3 more files need changes + edits them without re-approval*
```
**Why wrong:** Scope changed, requires return to step 1

**❌ Batched approval:**
```
Assistant: "I'll fix issues #1, #2, #3. Approve all?"
```
**Why wrong:** User should approve per bounded scope (max 2 files), not batch of arbitrary size

---

## Correct Pattern Examples

### Example 1: Patch with Approval Gate

```markdown
### Step 3: Execution approval

**Preflight:**
- Target files: `src/api/users.js`, `src/middleware/auth.js`
- Expected behavior: User creation will validate email format and reject invalid emails
- Verification: `npm test -- users.test.js` should pass email-validation tests

**Approval ask:**
Reply with "approve" to execute this scope.

### Step 4: Execute

[Wait for "approve" before proceeding]

1. Add email format validation in `src/api/users.js` (line 42)
2. Update auth middleware to check email validity
3. Reuse existing `validateEmail` helper (Duck Ladder rung 2)
4. Run `npm test -- users.test.js`
5. Report: Files changed, verification result, any issues
```

### Example 2: Scope Change During Execution

```markdown
**During execution:**

While fixing `src/api/users.js`, discovered that `src/models/user.js` also
needs validation at the model layer for database consistency.

**Scope change detected.**

**New preflight:**
- Additional file: `src/models/user.js`
- Additional behavior: Model-level email validation before database insert
- Updated verification: Run full test suite to confirm model + API validation

**Changes:**
- `src/models/user.js`: Add email validation at model layer

**Approval ask:**
Original scope completed. Reply with "approve" to execute additional model-layer change.

[Wait for approval before proceeding with model changes]
```

### Example 3: Cosmetic Change (Lightweight)

```markdown
### Step 2: Update documentation

**Change:**
Fix typo in README.md line 42: "authentification" -> "authentication"

**Confirm to proceed with doc change?**

[Acceptable confirmations: yes, confirm, ok, approve]
```

---

## Integration with Duck Ladder

Execution approval gate and Duck Ladder work together:

**Duck Ladder happens BEFORE approval ask:**
1. Gather evidence
2. Apply Duck Ladder (check 6 rungs)
3. Identify minimal safe diff
4. Present in preflight (files + behavior + verification)
5. Present list of changes broken down by file as formatted diff
6. Ask for approval
7. Wait
8. Execute minimal change

**Order:**
Evidence -> Duck Ladder -> Preflight -> Present Changes -> Approval -> Execute -> Verify

---

## Summary: Non-Negotiable Rules

1. ✅ All mutating actions require execution approval gate
2. ✅ Preflight must include: files (bounded), behavior, verification
3. ✅ Present list of changes broken down by file as formatted diff before approval ask
4. ✅ Approval ask must use exact phrase: "Reply with 'approve' to execute this scope."
5. ✅ Wait for "approve" token (not "continue", "yes", "ok")
6. ✅ Do not execute until "approve" received
7. ✅ Scope change triggers return to step 1 (new approval required)
8. ✅ Max 2 files for patch, max 5 for refactor (split if exceeded)
9. ✅ Cosmetic changes use lightweight confirmation
10. ✅ Refuse execution without bounded scope
11. ✅ Never bypass for safety carve-out violations

Apply this pattern when adapting external skills with mutating actions.
