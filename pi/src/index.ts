import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import {
  UNRECOGNIZED_CLARIFY_QUESTION,
  type KnownDuckling,
  type RouteDecision,
} from "./duck/routing.ts";
import {
  buildChainedTaskPayload,
  buildClarifiedTaskPayload,
  buildFollowupTaskPayload,
  buildWorkflowTaskPayload,
  preview,
} from "./core/text/task-payload.ts";
import { createRunControl } from "./duck/run-control.ts";
import { buildStatusLine, type DuckStatusRuntime } from "./duck/status.ts";
import { createInvokeAgent, type DuckInvokeContext } from "./duck/orchestrator.ts";
import { llmRoute } from "./duck/route-llm.ts";
import {
  applyWorkingStyle,
  extractMessageText,
  registerDuckMessageRenderers,
  sendRunBlock,
  sendUserInline,
  type UiFeedbackContext,
  withWorking,
} from "./platform/pi/ui-feedback.ts";
import {
  DEFAULT_STATE,
  STATE_ENTRY_TYPE,
  loadPersistedState,
  type DuckState,
} from "./duck/state.ts";
import {
  appendCappedInteraction,
  buildPendingWorkflow,
  workflowKickoffPrefix,
  type PendingClarification,
  type PendingFollowup,
  type PendingWorkflow,
} from "./duck/workflow-session.ts";
import {
  CLARIFY_PENDING_ROUTE_META,
  buildClarificationInput,
  isQuackInput,
  resolveFollowupContinuation,
  shouldIgnoreWorkflowTranscriptEntry,
  shouldSkipAmbientInput,
} from "./duck/input-flow.ts";
import { DUCK_USAGE } from "./duck/messages.ts";
import { registerDuckCommands } from "./duck/commands.ts";
import { DuckSupervisorStore, SUPERVISOR_ENTRY_TYPE, type SupervisorRun } from "./duck/supervisor.ts";

type DuckUiContext = DuckInvokeContext & UiFeedbackContext & {
  ui: DuckInvokeContext["ui"] & {
    setStatus(key: string, value: string | undefined): void;
    confirm?(title: string, message: string): Promise<boolean>;
  };
  sessionManager?: {
    getEntries(): Array<unknown>;
  };
};

function applyStatus(ctx: DuckUiContext, state: DuckState, runtime: DuckStatusRuntime): void {
  ctx.ui.setStatus("duck", buildStatusLine(state, runtime));
}

function routeMetaLine(route: Exclude<RouteDecision, null>): string {
  const chain = route.metaChain.length > 0 ? route.metaChain.join(" > ") : route.executionChain.join(" > ");
  return `route=${route.intent} skill=${route.skill} chain=${chain || "(none)"}`;
}

function dedupeChain(chain: KnownDuckling[]): KnownDuckling[] {
  const seen = new Set<KnownDuckling>();
  const out: KnownDuckling[] = [];
  for (const step of chain) {
    if (seen.has(step)) continue;
    seen.add(step);
    out.push(step);
  }
  return out;
}

export default function duckExtension(pi: ExtensionAPI): void {
  const supervisor = new DuckSupervisorStore();
  registerDuckMessageRenderers(pi);

  let state: DuckState = { ...DEFAULT_STATE };
  const runtime: DuckStatusRuntime = {};
  let lastRouteMeta = "route=(none) skill=(none) chain=(none)";
  let pendingClarification: PendingClarification = null;
  let pendingWorkflow: PendingWorkflow = null;
  let pendingWorkflowPrompted = false;
  let pendingFollowup: PendingFollowup = null;

  const clearPendingFollowup = () => {
    pendingFollowup = null;
  };

  const clearPendingWorkflow = () => {
    pendingWorkflow = null;
    pendingWorkflowPrompted = false;
    runtime.awaitingProceed = false;
  };

  const persistState = () => {
    pi.appendEntry(STATE_ENTRY_TYPE, { ...state });
  };

  const persistSupervisorOp = (op: unknown) => {
    pi.appendEntry(SUPERVISOR_ENTRY_TYPE, op);
  };

  const refreshStatus = (ctx: DuckUiContext) => {
    applyStatus(ctx, state, runtime);
  };

  const reset = (ctx: DuckUiContext) => {
    state = { ...DEFAULT_STATE };
    runtime.runningAgent = undefined;
    pendingClarification = null;
    clearPendingWorkflow();
    clearPendingFollowup();
    lastRouteMeta = "route=(none) skill=(none) chain=(none)";
    persistState();
    refreshStatus(ctx);
  };

  const invokeAgentImpl = createInvokeAgent({
    getState: () => state,
    persistState,
    refreshStatus,
  });

  const invokeAgent = async (agentName: string, task: string, ctx: DuckUiContext) => {
    runtime.runningAgent = agentName;
    refreshStatus(ctx);
    try {
      return await withWorking(ctx, `Running ${agentName}…`, async () => invokeAgentImpl(agentName, task, ctx));
    } finally {
      runtime.runningAgent = undefined;
      refreshStatus(ctx);
    }
  };

  const { continueRunExecution } = createRunControl<DuckUiContext>({
    supervisor,
    persistSupervisorOp,
    invokeAgent,
    sendRunBlock: (title, body, level, options, ctx) => sendRunBlock(pi, title, body, level, options, ctx),
    preview,
    buildChainedTaskPayload,
    getPendingFollowupInteractions: () => pendingFollowup?.interactions ?? [],
    setPendingFollowup: (value) => {
      pendingFollowup = value;
    },
    refreshStatus,
    clearActiveSkill: () => {
      runtime.activeSkill = undefined;
    },
  });

  const invokeSupervisorChain = async (
    params: {
      route: string;
      skill: string;
      chain: string[];
      task: string;
    },
    ctx: DuckUiContext,
  ) => {
    const run = supervisor.startRun(
      {
        route: params.route,
        skill: params.skill,
        chain: params.chain,
        task: params.task,
      },
      persistSupervisorOp,
    );
    supervisor.pruneTerminalRuns(20);

    runtime.activeSkill = params.skill;
    refreshStatus(ctx);

    sendRunBlock(
      pi,
      `Subagent chain started | Chain: ${params.chain.join(" -> ")}`,
      `Run ID: ${run.runId}`,
      "info",
      { forceExpanded: false, helperText: ["progress updates per completed step"] },
      ctx,
    );

    try {
      await continueRunExecution(run, ctx);
    } finally {
      runtime.activeSkill = undefined;
      refreshStatus(ctx);
    }
  };

  const invokeRouteChain = async (route: Exclude<RouteDecision, null>, task: string, ctx: DuckUiContext) => {
    const chain = dedupeChain(route.executionChain.length > 0 ? route.executionChain : [route.agent]);

    runtime.activeSkill = route.skill;
    refreshStatus(ctx);
    pendingWorkflow = buildPendingWorkflow(route, task, chain);
    clearPendingFollowup();
    pendingWorkflowPrompted = false;
    runtime.awaitingProceed = true;
    refreshStatus(ctx);

    const kickoff = [
      workflowKickoffPrefix(route.skill),
      "",
      task,
    ].join("\n");

    pi.sendUserMessage(kickoff);

    sendRunBlock(
      pi,
      "Workflow initialized",
      "",
      "info",
      {
        nonExpandable: true,
        helperText: ["continue chatting, or /duck proceed [summary] · /duck refine [--replace] <text> · /duck cancel"],
        notifyHelper: true,
      },
      ctx,
    );
    return;
  };

  const routeInput = async (input: string, ctx: DuckUiContext): Promise<RouteDecision> => {
    runtime.routing = true;
    refreshStatus(ctx);
    try {
      return await withWorking(ctx, "Routing…", async () => llmRoute(input, ctx.cwd));
    } finally {
      runtime.routing = false;
      refreshStatus(ctx);
    }
  };

  pi.on("session_start", async (_event, ctx) => {
    const entries = ctx.sessionManager?.getEntries?.();
    const persisted = loadPersistedState(entries);
    if (persisted) state = persisted;
    supervisor.hydrate(entries);
    supervisor.pruneTerminalRuns(20);
    applyWorkingStyle(ctx);
    refreshStatus(ctx);
  });

  pi.on("message_end", async (event) => {
    if (!pendingWorkflow) return;

    const message = (event as { message?: unknown }).message;
    const role = (message as { role?: unknown } | undefined)?.role;

    const text = extractMessageText(message);
    const kickoffPrefix = workflowKickoffPrefix(pendingWorkflow.route.skill);
    if (shouldIgnoreWorkflowTranscriptEntry({ role, text, kickoffPrefix })) return;

    pendingWorkflow.interactions = appendCappedInteraction(pendingWorkflow.interactions, {
      role: role as "user" | "assistant",
      text: preview(text, 1600),
    });
  });

  pi.on("input", async (event, ctx) => {
    const text = event.text ?? "";
    if (shouldSkipAmbientInput({ enabled: state.enabled, ambientMode: state.ambientMode, source: event.source, text })) {
      return { action: "continue" };
    }

    if (pendingWorkflow) {
      if (!pendingWorkflowPrompted) {
        sendRunBlock(
          pi,
          "Workflow pending",
          "",
          "info",
          {
            nonExpandable: true,
            helperText: ["continue chatting, or /duck proceed · /duck refine · /duck cancel"],
            notifyHelper: true,
          },
          ctx,
        );
        pendingWorkflowPrompted = true;
      }
      return { action: "continue" };
    }

    if (isQuackInput(text)) {
      const line = buildStatusLine(state, runtime) ?? "🦆 off";
      ctx.ui.notify(`${line}\n${lastRouteMeta}`, "info");
      return { action: "handled" };
    }

    if (pendingFollowup) {
      const userText = text.trim();
      const shouldContinueFollowup = await resolveFollowupContinuation(ctx.ui.confirm, pendingFollowup.runId);

      if (!shouldContinueFollowup) {
        clearPendingFollowup();
        ctx.ui.notify("Run follow-up closed. Routing this as a new request.", "info");
      } else {
        sendUserInline(pi, userText);
        await continueRunFollowup(userText, ctx);
        return { action: "handled" };
      }
    }

    if (pendingClarification) {
      const original = pendingClarification.original;
      const clarification = text.trim();
      const combined = buildClarificationInput(original, clarification);
      pendingClarification = null;

      sendUserInline(pi, buildClarifiedTaskPayload(original, clarification, 1200));

      const route = await routeInput(combined, ctx);
      if (!route) {
        pendingClarification = { original };
        lastRouteMeta = CLARIFY_PENDING_ROUTE_META;
        ctx.ui.notify(UNRECOGNIZED_CLARIFY_QUESTION, "info");
        return { action: "handled" };
      }

      lastRouteMeta = routeMetaLine(route);
      const taskPayload = buildClarifiedTaskPayload(original, clarification);
      await invokeRouteChain(route, taskPayload, ctx);
      return { action: "handled" };
    }

    sendUserInline(pi, text.trim());
    const route = await routeInput(text, ctx);

    if (!route) {
      pendingClarification = { original: text };
      lastRouteMeta = CLARIFY_PENDING_ROUTE_META;
      ctx.ui.notify(UNRECOGNIZED_CLARIFY_QUESTION, "info");
      return { action: "handled" };
    }

    lastRouteMeta = routeMetaLine(route);

    await invokeRouteChain(route, text, ctx);
    return { action: "handled" };
  });

  const continueRunFollowup = async (userReply: string, ctx: DuckUiContext) => {
    if (!pendingFollowup) {
      ctx.ui.notify("No active run follow-up. Start one by finishing a chain response.", "warning");
      return;
    }

    pendingFollowup.interactions = appendCappedInteraction(pendingFollowup.interactions, {
      role: "user",
      text: preview(userReply, 1600),
    });

    const followup = pendingFollowup;
    const task = buildFollowupTaskPayload(followup.baseTask, followup.interactions);

    await invokeSupervisorChain(
      {
        route: followup.route,
        skill: followup.skill,
        chain: followup.chain,
        task,
      },
      ctx,
    );
  };

  const closeRunFollowup = async (ctx: DuckUiContext) => {
    if (!pendingFollowup) {
      ctx.ui.notify("No active run follow-up.", "info");
      return;
    }
    clearPendingFollowup();
    ctx.ui.notify("Run follow-up context cleared.", "info");
  };

  const proceedWorkflow = async (args: string, ctx: DuckUiContext) => {
    if (!pendingWorkflow) {
      ctx.ui.notify("No pending workflow. Trigger one with a routed prompt first.", "warning");
      return;
    }

    const extra = (args ?? "").trim();
    const flow = pendingWorkflow;
    const task = buildWorkflowTaskPayload(flow, extra);

    sendRunBlock(
      pi,
      "Workflow preflight",
      [
        `Chain: ${flow.chain.join(" -> ")}`,
        `Refined: ${flow.refined ? "yes" : "no"}`,
        `Captured interactions: ${flow.interactions.length}`,
        `Task preview: ${preview(task, 240)}`,
      ].join("\n"),
      "info",
      { nonExpandable: true, helperText: ["running duckling chain"] },
      ctx,
    );

    clearPendingWorkflow();
    refreshStatus(ctx);

    await invokeSupervisorChain(
      {
        route: flow.route.intent,
        skill: flow.route.skill,
        chain: flow.chain,
        task,
      },
      ctx,
    );
  };

  const refineWorkflow = async (args: string, ctx: DuckUiContext) => {
    if (!pendingWorkflow) {
      ctx.ui.notify("No pending workflow to refine.", "warning");
      return;
    }

    const raw = (args ?? "").trim();
    if (!raw) {
      ctx.ui.notify(DUCK_USAGE.refine, "warning");
      return;
    }

    if (raw === "--replace") {
      ctx.ui.notify(DUCK_USAGE.refineReplace, "warning");
      return;
    }

    if (raw.startsWith("--replace ")) {
      const replacement = raw.slice("--replace ".length).trim();
      if (!replacement) {
        ctx.ui.notify(DUCK_USAGE.refineReplace, "warning");
        return;
      }
      pendingWorkflow.refinementContext = replacement;
      pendingWorkflow.refined = true;
      ctx.ui.notify("Pending workflow replaced. Use /duck proceed when ready.", "info");
      return;
    }

    pendingWorkflow.refinementContext = pendingWorkflow.refinementContext
      ? `${pendingWorkflow.refinementContext}\n${raw}`
      : raw;
    pendingWorkflow.refined = true;
    ctx.ui.notify("Pending workflow refined. Use /duck proceed when ready.", "info");
  };

  const cancelWorkflow = async (ctx: DuckUiContext) => {
    if (!pendingWorkflow) {
      ctx.ui.notify("No pending workflow.", "info");
      return;
    }
    clearPendingWorkflow();
    clearPendingFollowup();
    runtime.activeSkill = undefined;
    refreshStatus(ctx);
    ctx.ui.notify("Pending workflow canceled.", "info");
  };

  const listPendingRequests = async (ctx: DuckUiContext) => {
    const pending = supervisor.listPendingRequests();
    if (pending.length === 0) {
      ctx.ui.notify("No pending duck supervisor requests.", "info");
      return;
    }

    const lines = pending.map((req) => {
      const options = req.options?.join(", ") ?? "(freeform)";
      return [
        `- ${req.requestId}`,
        `  run=${req.runId} step=${req.step} agent=${req.agent}`,
        `  question=${req.question}`,
        `  options=${options}`,
        `  recommended=${req.recommended ?? "(none)"}`,
      ].join("\n");
    });

    ctx.ui.notify(`Pending requests (${pending.length}):\n${lines.join("\n")}`, "warning");
  };

  const listRuns = async (ctx: DuckUiContext) => {
    const runs = supervisor.listRuns(15);
    if (runs.length === 0) {
      ctx.ui.notify("No duck runs recorded yet.", "info");
      return;
    }

    const lines = runs.map(
      (run) =>
        `- ${run.runId} state=${run.state} step=${run.nextStep}/${run.totalSteps} route=${run.route ?? "(none)"} chain=${run.chain.join(" -> ")} started=${run.startedAt}`,
    );
    ctx.ui.notify(`Recent runs:\n${lines.join("\n")}`, "info");
  };

  const replyToRequest = async (args: string, ctx: DuckUiContext) => {
    const raw = (args ?? "").trim();
    if (!raw) {
      ctx.ui.notify(DUCK_USAGE.reply, "warning");
      return;
    }

    const firstSpace = raw.indexOf(" ");
    if (firstSpace < 0) {
      ctx.ui.notify(DUCK_USAGE.reply, "warning");
      return;
    }

    const requestId = raw.slice(0, firstSpace).trim();
    const remainder = raw.slice(firstSpace + 1).trim();
    if (!remainder) {
      ctx.ui.notify(DUCK_USAGE.reply, "warning");
      return;
    }

    const secondSpace = remainder.indexOf(" ");
    const decision = secondSpace < 0 ? remainder : remainder.slice(0, secondSpace).trim();
    const notes = secondSpace < 0 ? undefined : remainder.slice(secondSpace + 1).trim() || undefined;

    const allowedDecisions = new Set(["continue", "stop", "retry-later"]);
    if (!allowedDecisions.has(decision.toLowerCase())) {
      ctx.ui.notify("Invalid decision. Use: continue|stop|retry-later", "warning");
      return;
    }

    const replied = supervisor.replyRequest(requestId, decision, notes, persistSupervisorOp);
    if (!replied) {
      ctx.ui.notify(`Unknown request: ${requestId}`, "error");
      return;
    }

    const run = supervisor.getRun(replied.runId);
    if (!run) return;

    const normalized = decision.toLowerCase();
    if (normalized === "stop") {
      supervisor.setRunState(run.runId, "failed", persistSupervisorOp);
      sendRunBlock(
        pi,
        "Run stopped by supervisor decision",
        [`Run ID: ${run.runId}`, `Request ID: ${replied.requestId}`].join("\n"),
        "warning",
        { helperText: ["optional: /duck route preview <text>"] },
        ctx,
      );
      return;
    }

    if (normalized === "continue") {
      if (supervisor.hasPendingForRun(run.runId)) {
        sendRunBlock(
          pi,
          "Run still waiting on other requests",
          [`Run ID: ${run.runId}`].join("\n"),
          "warning",
          {
            helperText: ["use /duck pending, then reply to remaining requests"],
            notifyHelper: true,
          },
          ctx,
        );
        return;
      }

      const resumeFrom = Math.min(run.totalSteps + 1, replied.step + 1);
      supervisor.setRunNextStep(run.runId, resumeFrom, persistSupervisorOp);
      const refreshed = supervisor.getRun(run.runId);
      if (!refreshed) return;

      await continueRunExecution(refreshed, ctx);
    }
  };

  const resumeRun = async (args: string, ctx: DuckUiContext) => {
    const raw = (args ?? "").trim();
    if (!raw) {
      ctx.ui.notify("Usage: /duck resume <runId> [step]", "warning");
      return;
    }

    const parts = raw.split(/\s+/).filter(Boolean);
    const runId = parts[0];
    const run = supervisor.getRun(runId);
    if (!run) {
      ctx.ui.notify(`Unknown run: ${runId}`, "error");
      return;
    }

    if (supervisor.hasPendingForRun(runId)) {
      ctx.ui.notify(`Run ${runId} still has pending requests. Reply first via /duck reply.`, "warning");
      return;
    }

    const requestedStep = parts[1] ? Number.parseInt(parts[1], 10) : run.nextStep;
    const step = Number.isFinite(requestedStep) ? requestedStep : run.nextStep;
    supervisor.setRunNextStep(run.runId, step, persistSupervisorOp);
    const refreshed = supervisor.getRun(run.runId);
    if (!refreshed) return;

    await continueRunExecution(refreshed, ctx);
  };

  registerDuckCommands(pi, {
    getState: () => state,
    getStatusDetails: () => {
      const details: string[] = [];
      if (!pendingWorkflow) {
        details.push("- pending workflow: (none)");
      } else {
        details.push(`- pending workflow: ${pendingWorkflow.route.intent} · skill=${pendingWorkflow.route.skill}`);
        details.push(`- pending chain: ${pendingWorkflow.chain.join(" -> ")}`);
        details.push(`- pending interactions: ${pendingWorkflow.interactions.length}`);
        details.push(`- pending refinement chars: ${pendingWorkflow.refinementContext.length}`);
      }

      if (!pendingFollowup) {
        details.push("- run follow-up: (none)");
      } else {
        details.push(`- run follow-up: active (${pendingFollowup.runId})`);
        details.push(`- follow-up interactions: ${pendingFollowup.interactions.length}`);
      }

      return details;
    },
    persistState,
    refreshStatus,
    reset,
    invokeAgent,
    invokeSupervisorRun: async (agentName, task, ctx) => {
      await invokeSupervisorChain(
        {
          route: "manual",
          skill: "direct-duckling",
          chain: [agentName],
          task,
        },
        ctx as DuckUiContext,
      );
    },
    previewRoute: async (input, ctx) => {
      return withWorking(ctx as DuckUiContext, "Routing…", async () => llmRoute(input, ctx.cwd));
    },
    proceedWorkflow: async (args, ctx) => proceedWorkflow(args, ctx as DuckUiContext),
    refineWorkflow: async (args, ctx) => refineWorkflow(args, ctx as DuckUiContext),
    cancelWorkflow: async (ctx) => cancelWorkflow(ctx as DuckUiContext),
    listPendingRequests: async (ctx) => listPendingRequests(ctx as DuckUiContext),
    listRuns: async (ctx) => listRuns(ctx as DuckUiContext),
    replyToRequest: async (args, ctx) => replyToRequest(args, ctx as DuckUiContext),
    resumeRun: async (args, ctx) => resumeRun(args, ctx as DuckUiContext),
    continueRunFollowup: async (args, ctx) => continueRunFollowup(args, ctx as DuckUiContext),
    closeRunFollowup: async (ctx) => closeRunFollowup(ctx as DuckUiContext),
  });

}
