import { getMarkdownTheme, type ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Box, Container, Markdown, Spacer, Text } from "@earendil-works/pi-tui";
import {
  fallbackRouteAfterClarification,
  routeAmbient,
  UNRECOGNIZED_CLARIFY_QUESTION,
  type KnownDuckling,
  type RouteDecision,
} from "./duck/routing.ts";
import { buildStatusLine, type DuckStatusRuntime } from "./duck/status.ts";
import { createInvokeAgent, type DuckInvokeContext, type DuckInvokeResult } from "./duck/orchestrator.ts";
import {
  DEFAULT_STATE,
  STATE_ENTRY_TYPE,
  loadPersistedState,
  type DuckState,
} from "./duck/state.ts";
import { registerDuckCommands } from "./duck/commands.ts";
import { DuckSupervisorStore, SUPERVISOR_ENTRY_TYPE, type SupervisorRun } from "./duck/supervisor.ts";

type DuckUiContext = DuckInvokeContext & {
  ui: DuckInvokeContext["ui"] & {
    setStatus(key: string, value: string | undefined): void;
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

function preview(text: string, maxChars = 500): string {
  const trimmed = (text || "").trim();
  if (!trimmed) return "(no output)";
  if (trimmed.length <= maxChars) return trimmed;
  return `${trimmed.slice(0, maxChars)}\n\n[truncated ${trimmed.length - maxChars} chars]`;
}

function buildClarifiedTaskPayload(original: string, clarification: string, maxChars = 3000): string {
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

function sendRunBlock(
  pi: ExtensionAPI,
  title: string,
  body: string,
  level: "info" | "warning" | "error" = "info",
): void {
  const icon = level === "error" ? "🦆❌" : level === "warning" ? "🦆⚠️" : "🦆";
  pi.sendMessage({
    customType: "duck-subagent-run",
    content: `${icon} ${title}\n\n${body}`,
    display: true,
    details: { title, level },
  });
}

export default function duckExtension(pi: ExtensionAPI): void {
  const supervisor = new DuckSupervisorStore();

  pi.registerMessageRenderer("duck-subagent-run", (message, options, theme) => {
    const content = typeof message.content === "string" ? message.content : "";
    const lines = content.split("\n");
    const title = lines[0] ?? "🦆 Subagent";
    const body = lines.slice(1).join("\n").trim();

    const level = (message.details as { level?: "info" | "warning" | "error" } | undefined)?.level ?? "info";
    const titleColor = level === "error" ? "error" : level === "warning" ? "warning" : "toolTitle";

    const limit = 14;
    const bodyLines = body ? body.split("\n") : [];
    const showCollapsed = !options.expanded && bodyLines.length > limit;
    const visibleBody = showCollapsed ? bodyLines.slice(0, limit).join("\n") : body;

    const box = new Box(1, 1, (text) => theme.bg("customMessageBg", text));
    const container = new Container();
    container.addChild(new Text(theme.fg(titleColor, theme.bold(title)), 0, 0));

    if (visibleBody) {
      container.addChild(new Spacer(1));
      if (options.expanded) {
        container.addChild(new Markdown(visibleBody, 0, 0, getMarkdownTheme()));
      } else {
        container.addChild(new Text(theme.fg("toolOutput", visibleBody), 0, 0));
      }
    }

    if (showCollapsed) {
      container.addChild(new Spacer(1));
      container.addChild(
        new Text(theme.fg("muted", `... ${bodyLines.length - limit} more lines (Ctrl+O to expand)`), 0, 0),
      );
    }

    box.addChild(container);
    return box;
  });

  let state: DuckState = { ...DEFAULT_STATE };
  const runtime: DuckStatusRuntime = {};
  let lastRouteMeta = "route=(none) skill=(none) chain=(none)";
  let pendingClarification: { original: string } | null = null;

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
      return await invokeAgentImpl(agentName, task, ctx);
    } finally {
      runtime.runningAgent = undefined;
      refreshStatus(ctx);
    }
  };

  const executeRun = async (run: SupervisorRun, startStep: number, ctx: DuckUiContext) => {
    const results: Array<{ step: number; agent: string; result: DuckInvokeResult }> = [];

    for (let step = startStep; step <= run.chain.length; step++) {
      const agentName = run.chain[step - 1];
      supervisor.setRunNextStep(run.runId, step, persistSupervisorOp);

      sendRunBlock(
        pi,
        `Running ${agentName} (${step}/${run.chain.length})`,
        [
          `Run ID: ${run.runId}`,
          `Task passed to ${agentName}:`,
          "```text",
          run.task,
          "```",
        ].join("\n"),
        "info",
      );

      const result = await invokeAgent(agentName, run.task, ctx);
      results.push({ step, agent: agentName, result });

      if (!result.ok) {
        const req = supervisor.createRequest(
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
            },
          },
          persistSupervisorOp,
        );

        sendRunBlock(
          pi,
          `Subagent paused: ${agentName}`,
          [
            `Run ID: ${run.runId}`,
            `Request ID: ${req.requestId}`,
            `Exit code: ${result.exitCode}`,
            `stderr: ${result.stderr || "(none)"}`,
            "Output preview:",
            "```text",
            preview(result.output),
            "```",
            "Reply path:",
            "```text",
            `/duck-reply ${req.requestId} continue`,
            `/duck-resume ${run.runId}`,
            "```",
          ].join("\n"),
          "warning",
        );

        return { paused: true, results };
      }

      supervisor.setRunNextStep(run.runId, step + 1, persistSupervisorOp);

      sendRunBlock(
        pi,
        `Subagent complete: ${agentName}`,
        [
          `Run ID: ${run.runId}`,
          "Returned output preview:",
          "```text",
          preview(result.output),
          "```",
        ].join("\n"),
        "info",
      );
    }

    return { paused: false, results };
  };

  const finalizeRun = (run: SupervisorRun, results: Array<{ step: number; agent: string; result: DuckInvokeResult }>) => {
    const succeeded = results.filter((r) => r.result.ok);
    const failed = results.filter((r) => !r.result.ok);
    const finalOutput = succeeded.at(-1)?.result.output?.trim() || "";

    supervisor.setRunState(run.runId, failed.length > 0 ? "failed" : "completed", persistSupervisorOp);

    sendRunBlock(
      pi,
      "Subagent chain finished",
      [
        `Run ID: ${run.runId}`,
        `Succeeded: ${succeeded.length}`,
        `Failed: ${failed.length}`,
        "Steps:",
        ...results.map((r) =>
          r.result.ok
            ? `- ✅ step ${r.step} ${r.agent}`
            : `- ❌ step ${r.step} ${r.agent} (exit ${r.result.exitCode}${r.result.stderr ? `: ${r.result.stderr}` : ""})`,
        ),
      ].join("\n"),
      failed.length > 0 ? "warning" : "info",
    );

    if (finalOutput) {
      sendRunBlock(
        pi,
        "Final subagent output",
        [
          `Run ID: ${run.runId}`,
          "```text",
          preview(finalOutput, 3000),
          "```",
        ].join("\n"),
        "info",
      );
    }
  };

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

    sendRunBlock(
      pi,
      "Subagent chain started",
      [
        `Run ID: ${run.runId}`,
        `Route: ${params.route}`,
        `Skill: ${params.skill}`,
        `Execution chain: ${params.chain.join(" -> ")}`,
        "Pass-through task:",
        "```text",
        params.task,
        "```",
      ].join("\n"),
      "info",
    );

    const execution = await executeRun(run, run.nextStep, ctx);
    if (execution.paused) return;
    finalizeRun(run, execution.results);
  };

  const invokeRouteChain = async (route: Exclude<RouteDecision, null>, task: string, ctx: DuckUiContext) => {
    const chain = dedupeChain(route.executionChain.length > 0 ? route.executionChain : [route.agent]);
    await invokeSupervisorChain(
      {
        route: route.intent,
        skill: route.skill,
        chain,
        task,
      },
      ctx,
    );
  };

  pi.on("session_start", async (_event, ctx) => {
    const entries = ctx.sessionManager?.getEntries?.();
    const persisted = loadPersistedState(entries);
    if (persisted) state = persisted;
    supervisor.hydrate(entries);
    refreshStatus(ctx);
  });

  pi.on("input", async (event, ctx) => {
    const text = event.text ?? "";
    if (!state.enabled || !state.ambientMode) return { action: "continue" };
    if (event.source === "extension") return { action: "continue" };
    if (!text.trim() || text.trim().startsWith("/")) return { action: "continue" };

    if (text.trim().toLowerCase() === "quack") {
      const line = buildStatusLine(state, runtime) ?? "🦆 off";
      ctx.ui.notify(`${line}\n${lastRouteMeta}`, "info");
      return { action: "handled" };
    }

    if (pendingClarification) {
      const original = pendingClarification.original;
      const clarification = text.trim();
      const combined = `${original}\n\nClarification: ${clarification}`;
      pendingClarification = null;

      const route = routeAmbient(combined) ?? fallbackRouteAfterClarification(combined);
      lastRouteMeta = routeMetaLine(route);

      const taskPayload = buildClarifiedTaskPayload(original, clarification);
      await invokeRouteChain(route, taskPayload, ctx);
      return { action: "handled" };
    }

    const route = routeAmbient(text);
    if (!route) {
      pendingClarification = { original: text };
      lastRouteMeta = "route=clarify skill=(pending) chain=(pending)";
      ctx.ui.notify(UNRECOGNIZED_CLARIFY_QUESTION, "info");
      return { action: "handled" };
    }

    lastRouteMeta = routeMetaLine(route);

    await invokeRouteChain(route, text, ctx);
    return { action: "handled" };
  });

  registerDuckCommands(pi, {
    getState: () => state,
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
  });

  pi.registerCommand("duck-pending", {
    description: "List pending supervisor requests",
    handler: async (_args, ctx) => {
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
    },
  });

  pi.registerCommand("duck-runs", {
    description: "List recent duck runs",
    handler: async (_args, ctx) => {
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
    },
  });

  pi.registerCommand("duck-reply", {
    description: "Reply to a pending supervisor request: /duck-reply <requestId> <decision> [notes]",
    handler: async (args, ctx) => {
      const raw = (args ?? "").trim();
      if (!raw) {
        ctx.ui.notify("Usage: /duck-reply <requestId> <decision> [notes]", "warning");
        return;
      }

      const firstSpace = raw.indexOf(" ");
      if (firstSpace < 0) {
        ctx.ui.notify("Usage: /duck-reply <requestId> <decision> [notes]", "warning");
        return;
      }

      const requestId = raw.slice(0, firstSpace).trim();
      const remainder = raw.slice(firstSpace + 1).trim();
      if (!remainder) {
        ctx.ui.notify("Usage: /duck-reply <requestId> <decision> [notes]", "warning");
        return;
      }

      const secondSpace = remainder.indexOf(" ");
      const decision = secondSpace < 0 ? remainder : remainder.slice(0, secondSpace).trim();
      const notes = secondSpace < 0 ? undefined : remainder.slice(secondSpace + 1).trim() || undefined;

      const replied = supervisor.replyRequest(requestId, decision, notes, persistSupervisorOp);
      if (!replied) {
        ctx.ui.notify(`Unknown request: ${requestId}`, "error");
        return;
      }

      sendRunBlock(
        pi,
        "Supervisor reply recorded",
        [
          `Request ID: ${replied.requestId}`,
          `Run ID: ${replied.runId}`,
          `Decision: ${decision}`,
          `Notes: ${notes ?? "(none)"}`,
        ].join("\n"),
        "info",
      );

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
        );
        return;
      }

      if (normalized === "continue") {
        if (supervisor.hasPendingForRun(run.runId)) {
          sendRunBlock(
            pi,
            "Run still waiting on other requests",
            [`Run ID: ${run.runId}`, "Use /duck-pending and reply to remaining requests."].join("\n"),
            "warning",
          );
          return;
        }

        const resumeFrom = Math.min(run.totalSteps + 1, replied.step + 1);
        supervisor.setRunNextStep(run.runId, resumeFrom, persistSupervisorOp);
        const refreshed = supervisor.getRun(run.runId);
        if (!refreshed) return;

        sendRunBlock(
          pi,
          "Resuming run after supervisor reply",
          [`Run ID: ${run.runId}`, `Resume step: ${refreshed.nextStep}/${refreshed.totalSteps}`].join("\n"),
          "info",
        );

        const execution = await executeRun(refreshed, refreshed.nextStep, ctx);
        if (execution.paused) return;
        finalizeRun(refreshed, execution.results);
      }
    },
  });

  pi.registerCommand("duck-resume", {
    description: "Resume a duck run: /duck-resume <runId> [step]",
    handler: async (args, ctx) => {
      const raw = (args ?? "").trim();
      if (!raw) {
        ctx.ui.notify("Usage: /duck-resume <runId> [step]", "warning");
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
        ctx.ui.notify(`Run ${runId} still has pending requests. Reply first via /duck-reply.`, "warning");
        return;
      }

      const requestedStep = parts[1] ? Number.parseInt(parts[1], 10) : run.nextStep;
      const step = Number.isFinite(requestedStep) ? requestedStep : run.nextStep;
      supervisor.setRunNextStep(run.runId, step, persistSupervisorOp);
      const refreshed = supervisor.getRun(run.runId);
      if (!refreshed) return;

      sendRunBlock(
        pi,
        "Manual run resume",
        [`Run ID: ${run.runId}`, `Resume step: ${refreshed.nextStep}/${refreshed.totalSteps}`].join("\n"),
        "info",
      );

      const execution = await executeRun(refreshed, refreshed.nextStep, ctx);
      if (execution.paused) return;
      finalizeRun(refreshed, execution.results);
    },
  });
}
