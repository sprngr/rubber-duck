import type { KnownDuckling, RouteDecision } from "./routing.ts";

export type WorkflowInteraction = { role: "user" | "assistant"; text: string };

export type PendingClarification = { original: string } | null;

export type PendingWorkflow =
  | {
      route: Exclude<RouteDecision, null>;
      originalTask: string;
      refinementContext: string;
      interactions: WorkflowInteraction[];
      chain: KnownDuckling[];
      refined: boolean;
    }
  | null;

export type PendingFollowup =
  | {
      runId: string;
      route: string;
      skill: string;
      chain: string[];
      baseTask: string;
      interactions: WorkflowInteraction[];
    }
  | null;

export function appendCappedInteraction(
  interactions: WorkflowInteraction[],
  entry: WorkflowInteraction,
  maxEntries = 20,
): WorkflowInteraction[] {
  const max = Math.max(1, maxEntries);
  return [...interactions, entry].slice(-max);
}

export function buildPendingWorkflow(
  route: Exclude<RouteDecision, null>,
  originalTask: string,
  chain: KnownDuckling[],
): NonNullable<PendingWorkflow> {
  return {
    route,
    originalTask,
    refinementContext: "",
    interactions: [],
    chain,
    refined: false,
  };
}

export function buildPendingFollowup(input: {
  runId: string;
  route?: string;
  skill?: string;
  chain: string[];
  baseTask: string;
  priorInteractions: WorkflowInteraction[];
  assistantText: string;
}): NonNullable<PendingFollowup> {
  return {
    runId: input.runId,
    route: input.route ?? "manual",
    skill: input.skill ?? "direct-duckling",
    chain: [...input.chain],
    baseTask: input.baseTask,
    interactions: appendCappedInteraction(input.priorInteractions, { role: "assistant", text: input.assistantText }),
  };
}

export function workflowKickoffPrefix(skill: string, task:string): string {
  return `/${skill} ${task}; continue chat & wait for \`/duck proceed\`.`;
}
