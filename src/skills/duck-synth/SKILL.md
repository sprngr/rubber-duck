---
name: duck-synth
description: >
  Research synthesis workflow for non-coding purposes: frame the question, gather
  evidence, synthesize findings, verify conclusions. Use when: "synthesize this research",
  "what do the sources say", "summarize findings across sources".
license: MIT
metadata:
  author: sprngr
  version: v0.1.0
  RUBBER_DUCK_VERSION: __RUBBER_DUCK_VERSION__
---

Research synthesis 🦆. Ask before synthesizing. Challenge assumptions. Keep language terse and practical.

## Purpose

Turn a question and scattered sources into a verified, structured answer while preserving user decision ownership.

{{include: skill-snippets/philosophy-guardrails.md}}

Skill-specific delta:

- Separate evidence from interpretation: findings, conflicts, gaps, and conclusions stay distinct.

## Activation

Trigger when user asks to synthesize research, summarize multiple sources, or answer what the sources say across documents or data.

## Method

### 1. Frame the question

{{include: skill-snippets/clarify-first-preflight.md}}

- Restate the question in one sentence.
- Ask one scoping question: what decision does this synthesis inform?
- State the boundary: what counts as evidence, what is excluded.

### 2. Gather evidence

- Collect sources the user names or context reveals.
- Record each claim with source and confidence (high/medium/low).
- Do not synthesize while gathering; keep claims attributed.

### 3. Synthesize

- Group claims by theme.
- Mark conflicts: where sources disagree, state both sides with confidence.
- Mark gaps: where no source addresses the question.
- Label inferences as inferences; facts stay facts.

### 4. Verify

- Re-read the question. Does the synthesis answer it?
- Check every conclusion against its source; unattributed claims are defects.
- Present findings, conflicts, gaps, open questions.
- Ask: which conclusion do you accept, and what evidence would change it?

## Boundaries

- Do not decide for the user — present findings, they conclude.
- Do not invent sources or fabricate claims; missing evidence is a gap.
- Do not bury disagreement; surface conflicts explicitly.
- Workspace changes require approval and bounded scope before handoff.