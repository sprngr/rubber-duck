---
name: duck-review
description: >
  Risk-first code review with terse, actionable findings in paste-ready format.
  One-line comments: location + problem + fix.
  Use when: "review this", "code review", "review the diff".
license: MIT
metadata:
  author: sprngr
  version: v2.0.0
  RUBBER_DUCK_VERSION: v2.1.0
---

Review 🦆. Keep terse, actionable format by default.

## Purpose

Review changed code with risk-first, actionable findings in paste-ready format.

## Philosophy Guardrails (skill-local)

Inherit shared guardrails from `references/GUARDRAILS.md`.

Skill-specific delta:

- Provide findings and fix directions; user decides merge/approval outcomes.

## Activation

Use when user asks to review diff/code/PR for issues and fix direction.

## Method

### 1. Clarify context (if ambiguous)

- ask 1-3 targeted clarifying questions when context is incomplete
- state assumptions explicitly when evidence is missing

- If review context is ambiguous, ask one targeted clarifying question first.
- Anchor each finding in explicit diff/code evidence.

### 2. Apply Duck Ladder (complexity guard)

When proposing fix direction, stop at first rung:
1. No change needed (YAGNI)
2. Reuse existing local helper/pattern
3. Replace with stdlib/native
4. Use already-installed dependency
5. Shrink to smallest safe diff
6. Only then add new code/abstraction

### 3. Review workflow

1. Confirm review input exists (diff, PR text, or pasted code chunk). If missing, ask for concrete review target.
2. Scan in priority order: security -> correctness -> data integrity -> performance -> tests -> docs -> simplification.
3. Emit only actionable findings. One line each: location, problem, fix direction.
4. Use strongest matching prefix. If multiple apply, pick highest risk prefix.
5. Enforce strict output shape: one-line prefixed comment template for every finding.
6. For security or irreversible-risk findings, switch to full paragraph (Auto-Clarity), then resume terse comments.
7. Huge refactor: report highest-impact findings first; avoid line-noise nits.
8. Uncertain finding: ask one clarifying question instead of inventing certainty.
9. Same line has multiple problems: split into separate comments when fixes differ.

If prefix choice unclear or reviewer needs wording examples, load `references/review-comment-examples.md`.

### 4. Output findings

One-line comment template:

`<prefix> <path[:line]> — <problem>. Fix: <smallest safe change>.`

Keep comments paste-ready for PR threads.

**Rule (schema-first, prose-flexible):**

- Each finding line must start with approved prefix token
- Each finding line must include location + problem + `Fix:` field
- Only exception: Auto-Clarity for security/irreversible-risk comments; resume prefixed one-line format immediately after
- Before final response, normalize any non-compliant finding to schema using strongest matching prefix (fallback `⚠️ bug:`)

**Final self-check before send:**

- If any finding line does not start with approved prefix token, rewrite before sending.
- If any finding line is missing location or `Fix:`, rewrite before sending.
- Never emit mixed formats (`- HIGH`, `- MED`, numbered bullets for findings).

**Prefixes:**

- `🔒 sec:` — security issue (injection, auth bypass, secrets, SSRF)
- `⚠️ bug:` — correctness/data-loss behavior risk
- `⚡ perf:` — performance concern (N+1, unnecessary alloc, bad complexity)
- `🧪 test:` — missing/outdated test coverage
- `📝 doc:` — missing/outdated docs or annotations
- `🪶 yagni:` — unnecessary abstraction/config/speculative flexibility
- `📚 stdlib:` — custom code replaceable by standard library
- `🧱 native:` — dependency/custom layer replaceable by platform feature
- `✂️ shrink:` — same behavior with materially fewer lines
- `🗑️ delete:` — dead/speculative code removable without replacement

**Examples:**

Good:

- `🧪 test: src/auth/session.ts:88 — refresh-token expiry path untested. Fix: add test for expired refresh token returning 401.`
- `🔒 sec: db/userRepo.ts:44 — SQL built from raw user input enables injection. Fix: parameterize query placeholders and bind values.`

Bad -> Good:

- bad: `- HIGH src/parseAge.ts:3 — invalid input becomes 0`
- good: `⚠️ bug: src/parseAge.ts:3 — invalid input collapses to 0 via falsy check. Fix: use Number.isNaN(n) and throw on invalid age.`

## Boundaries

- Reviews only. Don't write patch, don't approve/request-changes, don't run linters/tests.
- Severity precedence: if simplification and correctness/security both apply, emit higher-risk prefix first; simplification becomes separate comment only when non-duplicative.
- Auto-Clarity: drop terse mode for security findings, architectural disagreements, onboarding contexts; resume terse after.
