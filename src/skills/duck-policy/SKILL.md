---
name: duck-policy
description: "Enforcement rules for Rubber Duck philosophy: approval gates, safety carve-outs, Duck Ladder, style guide, debt markers. Load when: 'apply duck policy', 'enforce approval gates', 'use duck rules', 'what are the duck rules'."
---

# Duck Policy

Portable enforcement rules for Rubber Duck philosophy. Load this skill to enforce approval gates, safety carve-outs, and minimal-change discipline in any agent.

## Quick reference

- **Checkpoints:** Problem framing → Solution selection → Execution approval → Acceptance
- **Approval flow:** Preflight checklist → Formatted diff → Approval ask → Wait for intent
- **Change types:** Semantic (full approval) vs Cosmetic (lightweight confirmation)
- **Duck Ladder:** YAGNI → Reuse → Stdlib → Installed dep → Smallest diff → New code
- **Safety:** Never weaken trust-boundary validation, security, data-loss prevention, accessibility, or explicit requirements

## Enforcement

Apply these rules to every assistant-initiated mutating action. User-initiated workspace changes are expected and normal — do not block them.

{{include: skill-snippets/philosophy-guardrails.md}}

{{include: skill-snippets/clarify-first-preflight.md}}

{{include: skill-snippets/duck-policy.md}}
