export const SUPERVISOR_ENTRY_TYPE = "rubber-duck.pi-extension.supervisor.v1";

export type SupervisorRunState = "running" | "needs_attention" | "completed" | "failed";

export type SupervisorRun = {
  runId: string;
  route?: string;
  skill?: string;
  chain: string[];
  task: string; // original task
  currentTask: string; // pass-through task for next step
  state: SupervisorRunState;
  nextStep: number; // 1-indexed pointer to next step to execute
  totalSteps: number;
  startedAt: string;
  updatedAt: string;
  completedAt?: string;
  activeSubagentId?: string;
};

export type SupervisorRequest = {
  requestId: string;
  runId: string;
  agent: string;
  step: number;
  blocking: boolean;
  question: string;
  options?: string[];
  recommended?: string;
  context?: Record<string, unknown>;
  createdAt: string;
  repliedAt?: string;
  decision?: string;
  notes?: string;
  status: "pending" | "replied";
};

type SupervisorOp =
  | { type: "run_started"; run: SupervisorRun }
  | { type: "run_state"; runId: string; state: SupervisorRunState; updatedAt: string; completedAt?: string }
  | { type: "run_cursor"; runId: string; nextStep: number; updatedAt: string }
  | { type: "run_task"; runId: string; currentTask: string; updatedAt: string }
  | { type: "run_active_subagent"; runId: string; agentId?: string; updatedAt: string }
  | { type: "request_created"; request: SupervisorRequest }
  | {
      type: "request_replied";
      requestId: string;
      decision: string;
      notes?: string;
      repliedAt: string;
    };

type PersistFn = (op: SupervisorOp) => void;

function nowIso(): string {
  return new Date().toISOString();
}

function makeId(prefix: string): string {
  return `${prefix}_${Date.now().toString(36)}_${Math.random().toString(36).slice(2, 8)}`;
}

export class DuckSupervisorStore {
  private runs = new Map<string, SupervisorRun>();
  private requests = new Map<string, SupervisorRequest>();

  private static readonly DEFAULT_PENDING_LIMIT = 100;
  private static readonly DEFAULT_RUN_LIMIT = 20;

  private sortedRunsDesc(): SupervisorRun[] {
    return Array.from(this.runs.values()).sort((a, b) => b.startedAt.localeCompare(a.startedAt));
  }

  private sortedPendingRequestsAsc(): SupervisorRequest[] {
    return Array.from(this.requests.values())
      .filter((req) => req.status === "pending")
      .sort((a, b) => a.createdAt.localeCompare(b.createdAt));
  }

  getPrunableRunIds(keepRecent = DuckSupervisorStore.DEFAULT_RUN_LIMIT): string[] {
    const safeKeep = Math.max(1, keepRecent);
    return this.sortedRunsDesc()
      .slice(safeKeep)
      .filter((run) => run.state === "completed" || run.state === "failed")
      .map((run) => run.runId);
  }

  pruneTerminalRuns(keepRecent = DuckSupervisorStore.DEFAULT_RUN_LIMIT): { removedRuns: number; removedRequests: number } {
    const removable = new Set(this.getPrunableRunIds(keepRecent));
    if (removable.size === 0) return { removedRuns: 0, removedRequests: 0 };

    let removedRuns = 0;
    for (const runId of removable) {
      if (this.runs.delete(runId)) removedRuns += 1;
    }

    let removedRequests = 0;
    for (const [requestId, request] of this.requests.entries()) {
      if (!removable.has(request.runId)) continue;
      if (request.status === "pending") continue;
      if (this.requests.delete(requestId)) removedRequests += 1;
    }

    return { removedRuns, removedRequests };
  }

  hydrate(entries: unknown[] | undefined): void {
    if (!entries?.length) return;

    for (const rawEntry of entries) {
      const entry = rawEntry as { type?: string; customType?: string; data?: unknown };
      if (entry?.type !== "custom") continue;
      if (entry?.customType !== SUPERVISOR_ENTRY_TYPE) continue;
      const op = entry.data as SupervisorOp | undefined;
      if (!op || typeof op !== "object") continue;
      this.apply(op, false);
    }
  }

  startRun(input: { route?: string; skill?: string; chain: string[]; task: string }, persist: PersistFn): SupervisorRun {
    const timestamp = nowIso();
    const run: SupervisorRun = {
      runId: makeId("run"),
      route: input.route,
      skill: input.skill,
      chain: input.chain,
      task: input.task,
      currentTask: input.task,
      state: "running",
      nextStep: 1,
      totalSteps: input.chain.length,
      startedAt: timestamp,
      updatedAt: timestamp,
    };

    const op: SupervisorOp = { type: "run_started", run };
    this.apply(op, true, persist);
    return run;
  }

  getRun(runId: string): SupervisorRun | null {
    return this.runs.get(runId) ?? null;
  }

  setRunState(runId: string, state: SupervisorRunState, persist: PersistFn): SupervisorRun | null {
    const run = this.runs.get(runId);
    if (!run) return null;

    const updatedAt = nowIso();
    const completedAt = state === "completed" || state === "failed" ? updatedAt : undefined;
    const op: SupervisorOp = { type: "run_state", runId, state, updatedAt, completedAt };
    this.apply(op, true, persist);
    return this.runs.get(runId) ?? null;
  }

  setRunNextStep(runId: string, nextStep: number, persist: PersistFn): SupervisorRun | null {
    const run = this.runs.get(runId);
    if (!run) return null;

    const bounded = Math.max(1, Math.min(nextStep, run.totalSteps + 1));
    const op: SupervisorOp = {
      type: "run_cursor",
      runId,
      nextStep: bounded,
      updatedAt: nowIso(),
    };
    this.apply(op, true, persist);
    return this.runs.get(runId) ?? null;
  }

  setRunCurrentTask(runId: string, currentTask: string, persist: PersistFn): SupervisorRun | null {
    const run = this.runs.get(runId);
    if (!run) return null;

    const op: SupervisorOp = {
      type: "run_task",
      runId,
      currentTask,
      updatedAt: nowIso(),
    };
    this.apply(op, true, persist);
    return this.runs.get(runId) ?? null;
  }

  setRunActiveSubagent(runId: string, agentId: string | undefined, persist: PersistFn): SupervisorRun | null {
    const run = this.runs.get(runId);
    if (!run) return null;

    const op: SupervisorOp = {
      type: "run_active_subagent",
      runId,
      agentId,
      updatedAt: nowIso(),
    };
    this.apply(op, true, persist);
    return this.runs.get(runId) ?? null;
  }

  createRequest(
    input: Omit<SupervisorRequest, "requestId" | "createdAt" | "status">,
    persist: PersistFn,
  ): SupervisorRequest {
    const request: SupervisorRequest = {
      ...input,
      requestId: makeId("req"),
      createdAt: nowIso(),
      status: "pending",
    };

    const op: SupervisorOp = { type: "request_created", request };
    this.apply(op, true, persist);

    // when pending requests exist, mark run as needs_attention
    this.setRunState(request.runId, "needs_attention", persist);

    return request;
  }

  getRequest(requestId: string): SupervisorRequest | null {
    return this.requests.get(requestId) ?? null;
  }

  hasPendingForRun(runId: string): boolean {
    for (const req of this.requests.values()) {
      if (req.runId === runId && req.status === "pending") return true;
    }
    return false;
  }

  replyRequest(requestId: string, decision: string, notes: string | undefined, persist: PersistFn): SupervisorRequest | null {
    const current = this.requests.get(requestId);
    if (!current) return null;
    if (current.status === "replied") return current;

    const op: SupervisorOp = {
      type: "request_replied",
      requestId,
      decision,
      notes,
      repliedAt: nowIso(),
    };
    this.apply(op, true, persist);

    const run = this.runs.get(current.runId);
    if (run && run.state === "needs_attention" && !this.hasPendingForRun(run.runId)) {
      this.setRunState(run.runId, "running", persist);
    }

    return this.requests.get(requestId) ?? null;
  }

  listPendingRequests(limit = DuckSupervisorStore.DEFAULT_PENDING_LIMIT): SupervisorRequest[] {
    const safeLimit = Math.max(1, limit);
    return this.sortedPendingRequestsAsc().slice(0, safeLimit);
  }

  listRuns(limit = DuckSupervisorStore.DEFAULT_RUN_LIMIT): SupervisorRun[] {
    const safeLimit = Math.max(1, limit);
    return this.sortedRunsDesc().slice(0, safeLimit);
  }

  getRunActiveSubagentId(runId: string): string | null {
    const run = this.runs.get(runId);
    if (!run) return null;
    return run.activeSubagentId ?? null;
  }

  private apply(op: SupervisorOp, shouldPersist: boolean, persist?: PersistFn): void {
    switch (op.type) {
      case "run_started": {
        this.runs.set(op.run.runId, {
          ...op.run,
          currentTask: op.run.currentTask ?? op.run.task,
          nextStep: Number.isFinite(op.run.nextStep) ? op.run.nextStep : 1,
          totalSteps: Number.isFinite(op.run.totalSteps) ? op.run.totalSteps : op.run.chain.length,
          activeSubagentId: op.run.activeSubagentId,
        });
        break;
      }
      case "run_state": {
        const run = this.runs.get(op.runId);
        if (!run) break;
        run.state = op.state;
        run.updatedAt = op.updatedAt;
        run.completedAt = op.completedAt ?? run.completedAt;
        if (op.state === "completed" || op.state === "failed") {
          run.activeSubagentId = undefined;
        }
        this.runs.set(run.runId, run);
        break;
      }
      case "run_cursor": {
        const run = this.runs.get(op.runId);
        if (!run) break;
        run.nextStep = op.nextStep;
        run.updatedAt = op.updatedAt;
        this.runs.set(run.runId, run);
        break;
      }
      case "run_task": {
        const run = this.runs.get(op.runId);
        if (!run) break;
        run.currentTask = op.currentTask;
        run.updatedAt = op.updatedAt;
        this.runs.set(run.runId, run);
        break;
      }
      case "run_active_subagent": {
        const run = this.runs.get(op.runId);
        if (!run) break;
        run.activeSubagentId = op.agentId;
        run.updatedAt = op.updatedAt;
        this.runs.set(run.runId, run);
        break;
      }
      case "request_created": {
        this.requests.set(op.request.requestId, { ...op.request });
        break;
      }
      case "request_replied": {
        const req = this.requests.get(op.requestId);
        if (!req) break;
        req.status = "replied";
        req.decision = op.decision;
        req.notes = op.notes;
        req.repliedAt = op.repliedAt;
        this.requests.set(req.requestId, req);
        break;
      }
    }

    if (shouldPersist && persist) persist(op);
  }
}
