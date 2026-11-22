---
name: duck-research
description: >
  Non-coding research synthesis: frame a question, grade sources, cite claims,
  surface conflicts and gaps, verify conclusions. Use when: "synthesize this
  research", "what do the sources say", "summarize findings across sources".
license: MIT
metadata:
  author: sprngr
  version: v1.0.0
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
- Ask one scoping question when the request names no decision and the answer would
  change the source set: what decision does this synthesis inform?
- Otherwise state the assumption and the evidence boundary in one line each: what
  counts as a source, what is excluded.

### 2. Gather evidence

- Collect only sources the user names or the workspace holds. Missing source:
  record the gap, do not substitute recollection.
- Three or more independent origins: build a ledger, one row per recorded
  statement, before analyzing it.

  | Claim | Source | Locator | Grade | Confidence |
  | --- | --- | --- | --- | --- |

- A row holds one statement: a figure, a quotation, or a finding. Rows reporting
  the same quantity concern one measure, whatever instrument produced it. A
  differing instrument is a comparability gap, not an exemption from conflict.
- Two origins or fewer: answer in prose with the source grade inline, no table.
- Inline grade means the source grade. Axis detail stays internal unless the user
  disputes a grade or asks which source is stronger; then show the four axis
  scores.
- Grade each source on tier, independence, recency, directness. Criteria:
  `references/grading-rubric.md`.
- Mark each row in the Claim cell: verbatim text in quotation marks, paraphrase
  unmarked. Keep claims attributed; grouping waits for synthesis.

### 3. Synthesize

- Group rows by theme. Each theme states what the evidence supports.
- Count origins, not named sources, for every threshold here. An origin counts once
  however many sources echo it, and it counts even when author, publisher, or
  method is undisclosed; that defect lowers its grade, not the count.
- Three to six origins: ledger shown, themes in prose.
- Three or more origins: echo rows fold into their origin, even below six.
- Presenting past six origins: one paragraph per theme, ledger in an appendix at
  one row per origin. Distinct origins keep their own row even when they agree.
  Where one origin carries several claims, the row lists them and takes its
  confidence from the weakest.
- Present disagreement as both sides with their grades. Do not average it into
  a middle claim.
- Label inferences. An inference inherits the grade of the weakest source it
  rests on.
- State gaps: sub-questions no source answers. An adjacent measured category does
  not license a claim about an unmeasured one.

### 4. Verify

- Re-read the question. Confirm the synthesis answers it and nothing beyond.
- Check each conclusion against ledger rows. A conclusion with no row is a
  defect: drop it or relabel it as inference.
- Re-examine low-grade rows carrying high-stakes conclusions.
- Present findings, conflicts, gaps. State open questions as unknowns, not as
  questions put to the user.
- Close with exactly one question: which conclusion the user accepts, and what
  evidence would change it. When the scoping question was asked, it is the
  answer's single question. That cap overrides any wider clarifying allowance.
- A shape the user specifies overrides the presentation rules. Keep the grades and
  the overall confidence, and keep the closing question on one line unless the
  shape forbids prose.

## Source grading

Score each source high/medium/low on four axes:

- **Tier**: high for primary evidence from the actor or instrument or for
  peer-reviewed work; medium for a named practitioner without a disclosed method;
  low for reporting of someone else's evidence or for unattributed material.
- **Independence**: high when its own origin; medium when it shares publisher,
  author, or method with another source in the set; low when it traces to another
  source in the set. Undisclosed author, publisher, or method scores low: the
  origin cannot be corroborated. Syndicated copies and summaries count once.
- **Recency**: high inside the question's time window, medium within twice that
  window, low beyond it or undated. No window stated and none implied by the
  question: apply five years and name it in one line. A window ends today; a
  year-only date counts from 1 January.
- **Directness**: high when the measure is the outcome the question names; medium
  when an objective proxy stands in (logged output, throughput, measured cycle
  time); low when the measure is reported second hand, or is self-perception,
  recollection, or an undisclosed estimate.

Leave no axis blank and do not average around one.

Source grade is the lowest axis score, per source. Two sources tie on grade: the
one with more axes scored high is stronger; still tied, the more recent is
stronger. Claim confidence is scored per ledger row, from the sources supporting
that row:

- **High**: two or more independent sources, at least one primary or
  peer-reviewed, agreeing.
- **Medium**: one solid source, or several sharing an origin.
- **Low**: single secondary source, indirect evidence, or conflict among the
  sources supporting the row.

Overall confidence is the highest row confidence the answer rests on, capped by
the conflict rule below. State it once in the findings prose.

Conflict is resolved only when the better-graded side holds two or more independent
sources at medium or above and the other side holds none above low. Every other
disagreement caps overall confidence at low.

Vendor-collected original data is primary on tier. A claim resting only on
vendor-collected data caps at medium confidence; the cap is a ceiling, so a lower
confidence stands. The tier is not demoted.

Downgrade one level when the sources supporting a row report different numbers for
the same measure, or when their scopes are incompatible, with a floor at low.
Numbers disagree when they differ in sign, or by ten or more percentage points of
the reported measure when no margin is stated. Differing publication dates or
populations without conflicting numbers are a stated gap, not a disagreement.
Otherwise report both values without ranking. Never merge disagreeing values into
one figure.

## Citation rules

- Every claim carries a locator: file and section, URL and heading, document
  and page. "The literature" is not a locator.
- Non-document sources keep their native address: thread and message id,
  transcript and timestamp, recording and timecode.
- Quote verbatim inside quotation marks; paraphrase otherwise. Never blend the
  two unmarked.
- Cite the source you read. Naming a citing source is not reading it.
- No source, no claim. Record the gap instead of filling it from memory.
- Two sources tracing to one origin are one source. Flag the shared origin.
- A waiver removes locators, not honesty: label every claim unverified, restate
  the waiver, keep source names.
- The source supplies no locator: write `no locator in source`. Never invent one.

## Boundaries

- Do not decide for the user. Present graded findings; the user concludes.
- Decision-shaped question: state what the evidence bounds, name the criteria it
  does not test, stop. No recommendation.
- Do not invent sources, locators, or dates. Missing evidence is a gap.
- Do not bury disagreement or flatten it into consensus.
- Workspace changes require approval and bounded scope before handoff.
