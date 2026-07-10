export function preview(text: string, maxChars = 500): string {
  const trimmed = (text || "").trim();
  if (!trimmed) return "(no output)";
  if (trimmed.length <= maxChars) return trimmed;
  return `${trimmed.slice(0, maxChars)}\n\n[truncated ${trimmed.length - maxChars} chars]`;
}

export function buildClarifiedTaskPayload(original: string, clarification: string, maxChars = 3000): string {
  const compact = [
    "Task:",
    original.trim(),
    "",
    "Clarification:",
    clarification.trim(),
  ]
    .join("\n")
    .trim();

  if (compact.length <= maxChars) return compact;
  return `${compact.slice(0, maxChars)}\n\n[truncated ${compact.length - maxChars} chars]`;
}

export function buildChainedTaskPayload(originalTask: string, previousOutput: string, maxChars = 5000): string {
  const text = [
    "Task:",
    originalTask.trim(),
    "",
    "Previous subagent output:",
    previousOutput.trim(),
  ]
    .join("\n")
    .trim();

  if (text.length <= maxChars) return text;
  return `${text.slice(0, maxChars)}\n\n[truncated ${text.length - maxChars} chars]`;
}

export function buildWorkflowTaskPayload(
  flow: {
    route: {
      skill: string;
    };
    originalTask: string;
    refinementContext: string;
    interactions: Array<{ role: "user" | "assistant"; text: string }>;
  },
  proceedSummary?: string,
  maxChars = 9000,
): string {
  const transcriptLines = flow.interactions.map((entry, index) => {
    const who = entry.role === "assistant" ? "Assistant" : "User";
    return `${index + 1}. ${who}: ${entry.text}`;
  });

  const body = [
    "Routed task:",
    flow.originalTask.trim(),
    "",
    `Skill context (${flow.route.skill}) interactions:`,
    transcriptLines.length > 0 ? transcriptLines.join("\n") : "(none captured)",
    "",
    "Refinement notes:",
    flow.refinementContext.trim() || "(none)",
    "",
    "Proceed summary:",
    proceedSummary?.trim() || "(none)",
    "",
    "Use all context above to execute the subagent chain.",
  ]
    .join("\n")
    .trim();

  if (body.length <= maxChars) return body;
  return `${body.slice(0, maxChars)}\n\n[truncated ${body.length - maxChars} chars]`;
}

export function buildFollowupTaskPayload(
  baseTask: string,
  interactions: Array<{ role: "user" | "assistant"; text: string }>,
  maxChars = 9000,
): string {
  const transcript = interactions
    .map((entry, index) => `${index + 1}. ${entry.role === "assistant" ? "Assistant" : "User"}: ${entry.text}`)
    .join("\n");

  const body = [
    "Original run task:",
    baseTask.trim(),
    "",
    "Follow-up conversation:",
    transcript || "(none)",
    "",
    "Continue the same subagent chain using this follow-up context.",
  ]
    .join("\n")
    .trim();

  if (body.length <= maxChars) return body;
  return `${body.slice(0, maxChars)}\n\n[truncated ${body.length - maxChars} chars]`;
}
