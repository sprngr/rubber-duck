# Confidence and Satisfaction Metrics

## Goal

Primary outcome for Rubber Duck strict mode: increase developer confidence and satisfaction by reinforcing understanding and control during development sessions.

## Measurement model

Use one primary KPI with supporting leading indicators.

### Primary KPI

**Developer Confidence Score (DCS)**

Weekly pulse survey (1–5 scale), average of two prompts:

1. “I understood why the selected solution was chosen.”
2. “I felt in control of technical decisions during the session.”

`DCS = mean(Q1, Q2)`

Track by week, team, and workflow type (debug/review/design/etc.).

## Leading indicators (session-level)

1. **Checkpoint Coverage Rate**
   - Percentage of sessions that include all required strict-mode checkpoints.
   - Target: `>= 90%`.

2. **Alternatives Coverage Rate**
   - Percentage of recommendation moments that include at least one alternative + tradeoffs.
   - Target: `>= 85%`.

3. **Assumption Transparency Rate**
   - Percentage of sessions where assumptions are explicitly labeled.
   - Target: `>= 90%`.

4. **Post-change Reversal Rate**
   - Percentage of accepted changes that are rolled back or quickly replaced due to misunderstanding.
   - Target: downward trend over 30 days.

5. **Clarification Friction Signal**
   - Number of “why this?” or “what changed?” follow-up questions per session after final report.
   - Target: downward trend without reducing checkpoint rigor.

## 30-day success targets (initial)

- `+20%` DCS improvement from baseline.
- `>= 90%` Checkpoint Coverage.
- `>= 85%` Alternatives Coverage.
- Measurable decline in reversal and post-change confusion signals.

## Instrumentation guidance

At minimum, log these event types:

- `checkpoint_problem_framing_shown`
- `checkpoint_solution_selection_shown`
- `checkpoint_scope_shown`
- `checkpoint_acceptance_shown`
- `user_approval_received`
- `assumption_declared`
- `alternatives_provided`
- `change_executed`
- `rollback_requested`

This event model allows confidence outcomes to be correlated with strict-mode adherence.

## Interpretation notes

- Rising question count is not automatically bad; it can indicate healthy critical engagement.
- Focus on whether confusion persists after checkpoints, not whether questions exist.
- Compare debug vs review workflows separately because baseline confidence differs by task type.

## Reporting cadence

- Weekly: KPI + leading indicators dashboard.
- Monthly: trend analysis, root-cause review for low-confidence sessions, policy adjustments.

## Action loop

1. Measure strict-mode adherence.
2. Identify weak checkpoints.
3. Adjust prompts/contracts for those checkpoints.
4. Re-measure confidence impact.

This loop keeps product behavior aligned with the core mission: developers should finish sessions more informed, more confident, and clearly in control.
