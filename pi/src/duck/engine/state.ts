import type { DuckEngineRun, DuckEngineRunStatus } from "./types.ts";

type RunPatch = Partial<Pick<DuckEngineRun, "status" | "output" | "error" | "activeAgentId">>;

function nowRun(input: {
  runId: string;
  step: number;
  agent: string;
  status?: DuckEngineRunStatus;
  output?: string;
  error?: string;
  activeAgentId?: string;
}): DuckEngineRun {
  return {
    runId: input.runId,
    step: input.step,
    agent: input.agent,
    status: input.status ?? "queued",
    output: input.output,
    error: input.error,
    activeAgentId: input.activeAgentId,
  };
}

export class DuckEngineState {
  private readonly runs = new Map<string, DuckEngineRun>();

  upsertRun(input: {
    runId: string;
    step: number;
    agent: string;
    status?: DuckEngineRunStatus;
    output?: string;
    error?: string;
    activeAgentId?: string;
  }): DuckEngineRun {
    const current = this.runs.get(input.runId);
    const next = current
      ? {
          ...current,
          step: input.step,
          agent: input.agent,
          status: input.status ?? current.status,
          output: input.output ?? current.output,
          error: input.error ?? current.error,
          activeAgentId: input.activeAgentId ?? current.activeAgentId,
        }
      : nowRun(input);

    this.runs.set(input.runId, next);
    return next;
  }

  patchRun(runId: string, patch: RunPatch): DuckEngineRun | undefined {
    const current = this.runs.get(runId);
    if (!current) return undefined;

    const next: DuckEngineRun = {
      ...current,
      status: patch.status ?? current.status,
      output: patch.output ?? current.output,
      error: patch.error ?? current.error,
      activeAgentId: patch.activeAgentId ?? current.activeAgentId,
    };
    this.runs.set(runId, next);
    return next;
  }

  clearActiveAgent(runId: string): DuckEngineRun | undefined {
    return this.patchRun(runId, { activeAgentId: undefined });
  }

  getRun(runId: string): DuckEngineRun | undefined {
    const run = this.runs.get(runId);
    return run ? { ...run } : undefined;
  }

  listRuns(): DuckEngineRun[] {
    return Array.from(this.runs.values()).map((run) => ({ ...run }));
  }
}
