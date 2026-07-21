# Harness-Specific Best Practices

Guidance for optimizing Rubber Duck behavior across different AI assistant harnesses.

## Overview

Rubber Duck ships the same core agent body to Claude, Copilot, and OpenCode, but each harness has different UX patterns and user expectations. This document provides tuning recommendations for operators who want to optimize for specific harness characteristics.

## Harness characteristics

### Claude Code
- **Context:** Conversational REPL with longer sessions
- **User expectation:** Thorough exploration, detailed explanations
- **Tool access:** Full tool suite including Agent delegation
- **Session length:** Typically longer (10+ turns)
- **User tolerance:** Higher for clarifying questions, detailed responses

### GitHub Copilot
- **Context:** Inline editor integration, quick iterations
- **User expectation:** Fast, actionable responses
- **Tool access:** Inline suggestions, limited multi-turn dialogue
- **Session length:** Typically shorter (1-5 turns)
- **User tolerance:** Lower for back-and-forth, prefer concise guidance

### OpenCode
- **Context:** Multi-agent orchestration, parallel execution
- **User expectation:** Agent coordination, structured workflows
- **Tool access:** Task delegation, parallel skill invocation
- **Session length:** Variable (workflow-driven)
- **User tolerance:** Moderate for questions, high for structured delegation

## Tuning recommendations by harness

### Claude Code optimizations

**Clarifying questions:**
- Use upper bound (2-3 questions for complex scenarios)
- More detailed question context acceptable
- Example: "What constraint drives this choice? Asking because I see three viable approaches with different tradeoffs..."

**Response depth:**
- Longer explanations acceptable (150-250 words for design decisions)
- Include reasoning chains
- Provide multiple alternatives with detailed tradeoffs

**Approval flow:**
- More verbose scope descriptions
- Include "why this approach" in execution approval
- Example preflight: "Target files: [A, B]. Expected change: refactor authentication to use middleware pattern (reduces duplication, centralizes auth logic). Verification: existing auth tests should pass without modification."

**Workflow suggestions:**
- Explicitly offer quack routing with brief rationale
- Present composition patterns: "This could benefit from duck-review followed by duck-risk"

### Copilot optimizations

**Clarifying questions:**
- Use lower bound (1 question maximum for simple requests)
- Terse question format
- Example: "Which file?" vs "Which file should I edit?"

**Response depth:**
- Shorter responses (50-100 words for simple requests)
- Bullet points over paragraphs
- Front-load actionable content

**Approval flow:**
- Concise scope descriptions
- Example preflight: "Files: A, B. Change: extract auth middleware. Test: auth tests pass."

**Workflow suggestions:**
- Quick skill suggestion without detailed explanation
- Example: "Try: quack refactor this" (vs "For structured refactoring workflow with reference tracking, try: quack refactor this")

**Code-first responses:**
- When answering "explain this code", prefer inline comments or short explanation over narrative
- Provide code snippets over procedural steps

### OpenCode optimizations

**Task delegation:**
- More proactive skill delegation suggestions
- Leverage parallel execution for independent subtasks
- Example: "I can run duck-review and duck-risk in parallel for comprehensive analysis"

**Workflow composition:**
- Explicitly present multi-skill workflows
- Example: "Workflow: (1) duck-debug trace mode, (2) duck-triage for test gaps, (3) duck-patch fix. Approve to run?"

**Clarifying questions:**
- Standard depth (1-3 questions)
- Offer "run with defaults" option for experienced users
- Example: "Need scope clarification. Or reply 'defaults' to proceed with standard workflow."

**Agent coordination:**
- Use skill invocation more than inline execution for complex tasks
- Suggest parallel investigation: "I can trace refs in parallel with test coverage analysis"

## Parameter guidance by harness

### Clarifying question limits

| Harness | Simple requests | Workflow requests | Complex/risky |
|---------|----------------|-------------------|---------------|
| Claude  | 1-2            | 2-3               | 3-4           |
| Copilot | 0-1            | 1-2               | 2             |
| OpenCode| 1              | 1-3               | 2-3           |

### Response length targets (words)

| Harness | Simple answer | Workflow frame | Design analysis |
|---------|--------------|----------------|-----------------|
| Claude  | 80-120       | 150-200        | 200-300         |
| Copilot | 40-80        | 80-120         | 120-180         |
| OpenCode| 60-100       | 120-180        | 180-250         |

### Execution approval verbosity

| Harness | Preflight detail | Reasoning included | Example length |
|---------|-----------------|-------------------|----------------|
| Claude  | High            | Yes (why approach)| 3-5 sentences  |
| Copilot | Low             | No (just what)    | 1-2 sentences  |
| OpenCode| Medium          | Optional          | 2-3 sentences  |

## Implementation approach

**Current state:** One body.md for all harnesses

**Option 1 (code changes):** Add conditional sections in body.md
```markdown
Clarify-first:
{{#if harness=claude}}
- If intent is unclear, ask 1-2 targeted clarifying questions (up to 3-4 for security/risky scenarios)
{{else if harness=copilot}}
- If intent is unclear, ask one targeted clarifying question (maximum 2 for risky scenarios)
{{else}}
- If intent is unclear, ask one targeted clarifying question (1-3 for security/risky scenarios)
{{/if}}
```

**Option 2 (documentation only, recommended):** Keep shared body.md, document best practices here

**Rationale for documentation-only approach:**
- Maintains single source of truth (easier to maintain)
- Current shared body already works well across all harnesses
- Differences are subtle optimizations, not core functionality
- Operators can apply tuning selectively based on user feedback
- Avoids template complexity and build system changes

## Operator tuning workflow

If you want to optimize for a specific harness:

1. **Measure first**: Track user friction points
   - Are users frustrated by too many questions? (tune down)
   - Are users unclear about what's happening? (tune up verbosity)
   - Are workflows too slow? (increase delegation)

2. **Apply targeted changes**:
   - Clone body.md to harness-specific variant if needed
   - Adjust parameters based on tables above
   - Test with representative prompts

3. **Document deviations**:
   - Note why harness-specific version exists
   - Link back to this best practices guide
   - Track user feedback on changes

## Trade-offs

### Shared body (current approach)
**Pros:**
- Single source of truth (easier maintenance)
- Consistent behavior across harnesses
- Simpler build system
- No template logic needed

**Cons:**
- Cannot optimize for harness-specific UX patterns
- One-size-fits-all may be suboptimal for edge cases

### Harness-specific bodies
**Pros:**
- Optimized for each harness's UX patterns
- Can leverage harness-specific features
- Better matches user expectations per harness

**Cons:**
- Maintenance burden (3x changes for updates)
- Risk of divergence (different behaviors per harness)
- More complex build system
- Harder to ensure policy consistency

## Recommendations

**For most users:** Keep shared body.md as-is
- Current implementation works well across all harnesses
- Best practices here can inform manual tweaks if needed
- Future conditional sections can be added if clear patterns emerge

**For power users with strong harness preference:**
- Fork body.md for specific harness
- Apply tuning from tables above
- Maintain fork as local customization
- Consider contributing successful patterns back

**For maintainers:**
- Monitor user feedback across harnesses
- If clear patterns emerge, consider adding lightweight conditional sections
- Prioritize policy consistency over harness optimization
- Document any harness-specific quirks here

## Future enhancements

Potential improvements if harness-specific tuning proves valuable:

1. **Minimal conditional sections**: Add `{{harness}}` checks for high-impact differences only (e.g., clarifying question limits)
2. **Override snippets**: Allow `overrides/claude.md` snippets to augment shared body without forking
3. **Telemetry-driven tuning**: Use usage data to identify harness-specific optimization opportunities
4. **User preference layer**: Allow individual users to tune verbosity/delegation regardless of harness

## Related documentation

- [Harness agent config model](./05-harness-agent-config.md) — metadata and build system
- [Adaptive Socratic policy](./03-adaptive-socratic-policy.md) — core questioning approach
- [Agent skill model](./02-agent-skill-model.md) — routing and delegation patterns
