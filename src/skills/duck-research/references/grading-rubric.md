<!--
asset-type: reference
loading: on demand (source grading step)
format: grading criteria, tier definitions, confidence scale, citation format
-->

# Source Grading Rubric

## Criteria

Four axes, scored high / medium / low. Source grade is the lowest axis score.

- **Tier**: what artifact the claim rests on.
- **Independence**: whether the source shares an origin with others in the set.
- **Recency**: whether it falls inside the question's time window.
- **Directness**: whether it measures or reports the thing asked about.

## Tier definitions

| Tier | Artifact | Examples |
| --- | --- | --- |
| Primary | Evidence from the actor or instrument | Filings, datasets, standards, logs |
| Reviewed | Peer-reviewed or method-disclosed | Journals, preprints with data |
| Expert | Named practitioner, no disclosed method | Practitioner essays, regulator guidance |
| Secondary | Reports someone else's evidence | News summaries, vendor pages |
| Unattributed | No author, date, or method | Aggregator posts, anonymous threads |

Tier caps confidence; it does not set it. A primary source that misreads its own
data stays wrong.

## Confidence scale

- **High**: two or more independent sources, at least one primary or reviewed,
  agreeing.
- **Medium**: one solid source, or several sharing an origin.
- **Low**: single secondary source, indirect evidence, or unresolved conflict.

Downgrade one level when sources disagree on number, date, or scope. Downgrade
two levels for high-stakes questions.

## Citation format

- `<source> | <locator> | <verbatim|paraphrase>`, one citation per ledger row.
- Locator: file and section, URL and heading, document and page.
- Several sources for one claim become several rows.
- Missing locator means unverifiable: record a gap.
