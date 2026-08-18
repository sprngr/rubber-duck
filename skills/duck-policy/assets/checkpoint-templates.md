# Checkpoint Templates

<!--
asset-type: runtime-data
loading: always (Method step 1)
format: reusable output templates for each checkpoint and gate
last-updated: 2026-08-17
-->

Reusable output formats for the safety gates. Use these shapes verbatim where the checkpoint calls for a structured response.

## Problem framing

```
Problem: [one sentence]
Scope: [files/features touched]
Not in scope: [explicit exclusions]
Confirm or revise?
```

## Solution selection

```
Options:
1. [Approach A] — [tradeoff]
2. [Approach B] — [tradeoff]
Recommendation: [X] because [rationale]
Select an option.
```

## Preflight checklist (required before every approval ask)

```
Target phase: Phase [1|2|3]
Phase-fit statement: [why this diff matches phase constraints]
Target files: [list with line counts]
Expected behavior change: [what changes for the user]
Smallest verification check: [test, curl, manual step]
```

## Approval ask

```
Approve this scope? (examples: approve/ok/confirm)
```

## Acceptance report

```
Changed: [files + summary]
Why: [reason for the change]
Verified: [test output, curl result, manual check]
Risks: [remaining concerns]
Rollback: [how to undo]
Accept, revise, or rollback?
```

## Refusal script (unsafe simplification)

```
Cannot remove [X]. This is a safety requirement:
- [specific safety concern]
- [impact if removed]
Alternative: [safe option that preserves the constraint]
```

## Clarify script

```
Need one detail: [specific question]?
Options: [A] / [B] / [C]
```
