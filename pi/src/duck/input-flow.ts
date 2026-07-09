export function shouldSkipAmbientInput(input: {
  enabled: boolean;
  ambientMode: boolean;
  source?: string;
  text: string;
}): boolean {
  if (!input.enabled || !input.ambientMode) return true;
  if (input.source === "extension") return true;
  return !input.text.trim() || input.text.trim().startsWith("/");
}

export function isQuackInput(text: string): boolean {
  return text.trim().toLowerCase() === "quack";
}

export function shouldIgnoreWorkflowTranscriptEntry(entry: {
  role: unknown;
  text: string;
  kickoffPrefix: string;
}): boolean {
  if (entry.role !== "assistant" && entry.role !== "user") return true;
  if (!entry.text) return true;
  if (entry.role === "user" && entry.text.startsWith("/")) return true;
  if (entry.role === "user" && entry.text.startsWith(entry.kickoffPrefix)) return true;
  return false;
}

export async function resolveFollowupContinuation(
  confirm: ((title: string, message: string) => Promise<boolean>) | undefined,
  runId: string,
): Promise<boolean> {
  if (!confirm) return true;
  return confirm(`Continue run ${runId}?`, "Use this message as follow-up context for the last subagent run?");
}

export function buildClarificationInput(original: string, clarification: string): string {
  return `${original}\n\nClarification: ${clarification}`;
}

export const CLARIFY_PENDING_ROUTE_META = "route=clarify skill=(pending) chain=(pending)";
