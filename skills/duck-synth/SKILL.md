---
name: duck-synth
description: >
  Non-coding research synthesis: frame a question, grade sources, cite claims,
  surface conflicts and gaps, verify conclusions. Use when: "synthesize this
  research", "what do the sources say", "summarize findings across sources".
license: MIT
metadata:
  author: sprngr
  version: v0.1.0
  RUBBER_DUCK_VERSION: v3.2.0
---

Research synthesis 🦆. Grade evidence before trusting it. Cite every claim.

## Purpose

Turn a question and scattered sources into a structured answer with graded
evidence, traceable citations, and explicit gaps.

## Philosophy Guardrails (skill-local)

Inherit shared guardrails from `references/GUARDRAILS.md`.
- ask 1-3 targeted clarifying questions when context is incomplete
- state assumptions explicitly when evidence is missing

Skill-specific delta:

- Separate evidence from interpretation. Findings, conflicts, gaps, inferences,
  and conclusions stay distinct sections.
- Grade sources before weighing claims. Recollection is not a source.

## Activation

Trigger on "synthesize this research", "what do the sources say", "summarize
findings across sources", or any request spanning multiple documents or data
sets. Not for single-source lookup: read the source and answer.

## Method

### 1. Frame the question

- Restate the question in one sentence.
- Ask one scoping question: what decision does this synthesis inform?
- State the evidence boundary: what counts as a source, what is excluded.
- Wait for the answer when the boundary changes the source set.

### 2. Gather evidence

- Collect only sources the user names or the workspace holds. Missing source:
  record the gap, do not substitute recollection.
- Record every claim as one ledger row before analyzing it:

  | Claim | Source | Locator | Grade | Confidence |
  | --- | --- | --- | --- | --- |

- Grade each source on tier, independence, recency, directness. Criteria:
  `references/grading-rubric.md`.
- Mark each row verbatim or paraphrase. Keep claims attributed; do not group
  or rank while gathering.

### 3. Synthesize

- Group rows by theme. Each theme states what the evidence supports.
- Present disagreement as both sides with their grades. Do not average it into
  a middle claim.
- Label inferences. An inference inherits the grade of its weakest source.
- State gaps: sub-questions no source answers.

### 4. Verify

- Re-read the question. Confirm the synthesis answers it and nothing beyond.
- Check each conclusion against ledger rows. A conclusion with no row is a
  defect: drop it or relabel it as inference.
- Re-examine low-grade rows carrying high-stakes conclusions.
- Present findings, conflicts, gaps, open questions.
- Ask which conclusion the user accepts and what evidence would change it.

## Source grading

Score each source high/medium/low on four axes:

- **Tier**: primary document or dataset, peer-reviewed work, expert secondary,
  general secondary, unattributed summary.
- **Independence**: own origin. Syndicated copies count once.
- **Recency**: publication date against the question's time window.
- **Directness**: answers the question, or stands in as a proxy.

Source grade caps claim confidence. A medium-tier source needs independent
corroboration before it supports high confidence.

## Citation rules

- Every claim carries a locator: file and section, URL and heading, document
  and page. "The literature" is not a locator.
- Quote verbatim inside quotation marks; paraphrase otherwise. Never blend the
  two unmarked.
- Cite the source you read. Naming a citing source is not reading it.
- No source, no claim. Record the gap instead of filling it from memory.
- Two sources tracing to one origin are one source. Flag the shared origin.

## Boundaries

- Do not decide for the user. Present graded findings; the user concludes.
- Do not invent sources, locators, or dates. Missing evidence is a gap.
- Do not bury disagreement or flatten it into consensus.
- Workspace changes require approval and bounded scope before handoff.
