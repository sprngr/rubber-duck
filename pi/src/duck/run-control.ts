import { buildPendingFollowup, type PendingFollowup, type WorkflowInteraction } from "./workflow-session.ts";
import type { DuckInvokeResult } from "./orchestrator.ts";
import type { SupervisorRun, DuckSupervisorStore } from "./supervisor.ts";

type RunStepResult = { step: number; agent: string; result: DuckInvokeResult };

type RunControlContext<Context> = {
  supervisor: DuckSupervisorStore;
  persistSupervisorOp(op: unknown): void;
  invokeAgent(agentName: string, task: string, ctx: Context): Promise<DuckInvokeResult>;
  sendRunBlock(
    title: string,
    body: string,
    level: "info" | "warning" | "error",
    options: {
      forceExpanded?: boolean;
      nonExpandable?: boolean;
      helperText?: string[];
      notifyHelper?: boolean;
    },
    ctx: Context,
  ): void;
  debugEnabled(): boolean;
  debugVerboseEnabled(): boolean;
  sendDebug(title: string, body: string, ctx: Context): void;
  preview(text: string, maxChars?: number): string;
  buildChainedTaskPayload(originalTask: string, previousOutput: string): string;
  getPendingFollowupInteractions(): WorkflowInteraction[];
  getPendingFollowupBaseTask(): string | undefined;
  setPendingFollowup(value: PendingFollowup): void;
  refreshStatus(ctx: Context): void;
  clearActiveSkill(): void;
};

export function createRunControl<Context>(deps: RunControlContext<Context>) {
  const executeRun = async (run: SupervisorRun, startStep: number, ctx: Context) => {
    const results: RunStepResult[] = [];
    let currentTask = (run.currentTask || run.task || "").trim();

    for (let step = startStep; step <= run.chain.length; step++) {
      const agentName = run.chain[step - 1];
      deps.supervisor.setRunNextStep(run.runId, step, deps.persistSupervisorOp);

      if (deps.debugEnabled()) {
        const maxChars = deps.debugVerboseEnabled() ? 6000 : 1800;
        deps.sendDebug(
          `step ${step}/${run.chain.length} in (${agentName})`,
          [
            `Run ID: ${run.runId}`,
            `Task preview: ${deps.preview(currentTask, maxChars)}`,
          ].join("\n"),
          ctx,
        );
      }

      let result: DuckInvokeResult;
      try {
        result = await deps.invokeAgent(agentName, currentTask, ctx);
      } catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        result = {
          ok: false,
          output: "",
          exitCode: 1,
          stderr: message || "Unknown invokeAgent error",
        };
      }
      results.push({ step, agent: agentName, result });

      if (deps.debugEnabled()) {
        const maxChars = deps.debugVerboseEnabled() ? 6000 : 1800;
        deps.sendDebug(
          `step ${step}/${run.chain.length} out (${agentName})`,
          [
            `Run ID: ${run.runId}`,
            `ok=${result.ok} exit=${result.exitCode}`,
            `stderr: ${result.stderr || "(none)"}`,
            `Output preview: ${deps.preview(result.output || "", maxChars)}`,
          ].join("\n"),
          ctx,
        );
      }

      if (!result.ok) {
        const req = deps.supervisor.createRequest(
          {
            runId: run.runId,
            agent: agentName,
            step,
            blocking: true,
            question: `Subagent ${agentName} failed at step ${step}. How should we proceed?`,
            options: ["continue", "stop", "retry-later"],
            recommended: "continue",
            context: {
              exitCode: result.exitCode,
              stderr: result.stderr || "",
              taskUsed: deps.preview(currentTask, 800),
            },
          },
          deps.persistSupervisorOp,
        );

        deps.sendRunBlock(
          `Subagent paused: ${agentName}`,
          [
            `Run ID: ${run.runId}`,
            `Request ID: ${req.requestId}`,
            `Exit code: ${result.exitCode}`,
            `stderr: ${result.stderr || "(none)"}`,
            "Output preview:",
            "```text",
            deps.preview(result.output),
            "```",
          ].join("\n"),
          "warning",
          {
            helperText: [`reply: /duck reply ${req.requestId} continue · /duck resume ${run.runId}`],
            notifyHelper: true,
          },
          ctx,
        );

        return { paused: true, results };
      }

      deps.supervisor.setRunNextStep(run.runId, step + 1, deps.persistSupervisorOp);
      if (result.output?.trim()) {
        currentTask = deps.buildChainedTaskPayload(run.task, result.output);
        deps.supervisor.setRunCurrentTask(run.runId, currentTask, deps.persistSupervisorOp);
      }
    }

    return { paused: false, results };
  };

  const finalizeRun = (run: SupervisorRun, results: RunStepResult[], ctx: Context) => {
    const succeeded = results.filter((r) => r.result.ok);
    const failed = results.filter((r) => !r.result.ok);
    const finalOutput = succeeded.at(-1)?.result.output?.trim() || "";

    deps.supervisor.setRunState(run.runId, failed.length > 0 ? "failed" : "completed", deps.persistSupervisorOp);

    const failedLines = failed.map(
      (r) => `- ❌ step ${r.step} ${r.agent} (exit ${r.result.exitCode}${r.result.stderr ? `: ${r.result.stderr}` : ""})`,
    );

    const responseSections = [
      ...(failedLines.length > 0 ? ["Failures:", ...failedLines, ""] : []),
      finalOutput ? finalOutput : "(no final output)",
    ];

    deps.sendRunBlock(
      `Subagent response | Run ID: ${run.runId}`,
      responseSections.join("\n"),
      failed.length > 0 ? "warning" : "info",
      {
        forceExpanded: true,
        helperText: [
          failed.length > 0
            ? "inspect failures; then choose next step"
            : "reply to continue run context (ambient on) · /duck followup <text> · /duck close-run",
        ],
      },
      ctx,
    );

    const priorFollowup = deps.getPendingFollowupInteractions();
    const stableBaseTask = deps.getPendingFollowupBaseTask() ?? run.task;

    deps.setPendingFollowup(
      buildPendingFollowup({
        runId: run.runId,
        route: run.route,
        skill: run.skill,
        chain: run.chain,
        baseTask: stableBaseTask,
        priorInteractions: priorFollowup,
        assistantText: deps.preview(finalOutput || "(no final output)", 1600),
      }),
    );

    deps.clearActiveSkill();
    deps.refreshStatus(ctx);
  };

  const continueRunExecution = async (run: SupervisorRun, ctx: Context) => {
    const execution = await executeRun(run, run.nextStep, ctx);
    if (execution.paused) return;
    finalizeRun(run, execution.results, ctx);
  };

  return {
    continueRunExecution,
  };
}
