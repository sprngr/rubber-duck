import { getMarkdownTheme, type ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Box, Container, Markdown, Spacer, Text } from "@earendil-works/pi-tui";
import * as fs from "node:fs";
import * as path from "node:path";
import { fileURLToPath } from "node:url";
import {
  UNRECOGNIZED_CLARIFY_QUESTION,
  type KnownDuckling,
  type RouteDecision,
} from "./duck/routing.ts";
import { buildStatusLine, type DuckStatusRuntime } from "./duck/status.ts";
import { createInvokeAgent, type DuckInvokeContext, type DuckInvokeResult } from "./duck/orchestrator.ts";
import type { DuckAgentConfig } from "./duck/agents.ts";
import { runDuckAgent } from "./duck/runner.ts";
import {
  DEFAULT_STATE,
  STATE_ENTRY_TYPE,
  loadPersistedState,
  type DuckState,
} from "./duck/state.ts";
import { registerDuckCommands } from "./duck/commands.ts";
import { DuckSupervisorStore, SUPERVISOR_ENTRY_TYPE, type SupervisorRun } from "./duck/supervisor.ts";
import { randomDuckWorkingAction } from "./duck/working.ts";

type WorkingIndicatorOptions = {
  frames: string[];
  intervalMs?: number;
};

type DuckUiContext = DuckInvokeContext & {
  ui: DuckInvokeContext["ui"] & {
    setStatus(key: string, value: string | undefined): void;
    setWorkingMessage?(message?: string): void;
    setWorkingVisible?(visible: boolean): void;
    setWorkingIndicator?(options?: WorkingIndicatorOptions): void;
    setWidget?(key: string, content: string[] | undefined): void;
    confirm?(title: string, message: string): Promise<boolean>;
    theme: {
      fg(color: string, text: string): string;
    };
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

function stripFencedBackticks(text: string): string {
  return text
    .split("\n")
    .filter((line) => {
      const t = line.trim();
      return t !== "```" && t !== "```text";
    })
    .join("\n");
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

function buildChainedTaskPayload(originalTask: string, previousOutput: string, maxChars = 5000): string {
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

function extractMessageText(message: unknown): string {
  if (!message || typeof message !== "object") return "";
  const content = (message as { content?: unknown }).content;
  if (typeof content === "string") return content.trim();

  if (Array.isArray(content)) {
    return content
      .map((part) => {
        if (!part || typeof part !== "object") return "";
        const p = part as { type?: unknown; text?: unknown };
        if (p.type === "text" && typeof p.text === "string") return p.text;
        return "";
      })
      .filter(Boolean)
      .join("\n")
      .trim();
  }

  return "";
}

function buildWorkflowTaskPayload(
  flow: {
    route: Exclude<RouteDecision, null>;
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

function buildFollowupTaskPayload(
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

function sendRunBlock(
  pi: ExtensionAPI,
  title: string,
  body: string,
  level: "info" | "warning" | "error" = "info",
  options?: {
    forceExpanded?: boolean;
    nonExpandable?: boolean;
    helperText?: string[];
    notifyHelper?: boolean;
  },
  ctx?: DuckUiContext,
): void {
  const icon = level === "error" ? "🦆❌" : level === "warning" ? "🦆⚠️" : "🦆";
  pi.sendMessage({
    customType: "duck-subagent-run",
    content: `${icon} ${title}${body ? '\n\n' + body : ''}`,
    display: true,
    details: {
      title,
      level,
      forceExpanded: options?.forceExpanded === true,
      nonExpandable: options?.nonExpandable === true,
    },
  });

  if (options?.notifyHelper && options.helperText && ctx) {
    ctx.ui.notify(options.helperText.join(" · "), level === "error" ? "error" : level === "warning" ? "warning" : "info");
  }
}

function sendUserInline(pi: ExtensionAPI, text: string): void {
  pi.sendMessage({
    customType: "duck-user-input",
    content: text,
    display: true,
  });
}

const WORKING_SPINNER_FRAMES = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"];

function applyWorkingStyle(ctx: DuckUiContext): void {
  ctx.ui.setWorkingVisible?.(true);
  ctx.ui.setWorkingIndicator?.({
    frames: WORKING_SPINNER_FRAMES.map((frame) => ctx.ui.theme.fg("accent", frame)),
    intervalMs: 80,
  });
}

function startInlineWorking(ctx: DuckUiContext, message: string): () => void {
  if (!ctx.ui.setWidget) return () => {};

  let frameIndex = 0;
  const render = () => {
    const frame = WORKING_SPINNER_FRAMES[frameIndex % WORKING_SPINNER_FRAMES.length] ?? "⠋";
    ctx.ui.setWidget("duck-working-inline", [
      `${ctx.ui.theme.fg("warning", frame)} ${ctx.ui.theme.fg("dim", message)}`,
    ]);
    frameIndex += 1;
  };

  render();
  const timer = setInterval(render, 80);

  return () => {
    clearInterval(timer);
    ctx.ui.setWidget?.("duck-working-inline", undefined);
  };
}

async function withWorking<T>(ctx: DuckUiContext, _message: string, fn: () => Promise<T>): Promise<T> {
  const indicatorText = randomDuckWorkingAction();
  ctx.ui.setWorkingVisible?.(true);
  ctx.ui.setWorkingMessage?.(indicatorText);
  const stopInline = startInlineWorking(ctx, indicatorText);
  try {
    return await fn();
  } finally {
    stopInline();
    ctx.ui.setWorkingMessage?.();
  }
}

function stripFrontmatter(markdown: string): string {
  if (!markdown.startsWith("---\n")) return markdown;
  const end = markdown.indexOf("\n---\n", 4);
  if (end < 0) return markdown;
  return markdown.slice(end + 5);
}

function readBundledRouterPrompt(): string {
  const here = path.dirname(fileURLToPath(import.meta.url));
  const candidates = [
    path.resolve(here, "../agents/rubber-duck.md"),
    path.resolve(here, "../../agents/rubber-duck.md"),
  ];

  for (const candidate of candidates) {
    if (fs.existsSync(candidate)) {
      return stripFrontmatter(fs.readFileSync(candidate, "utf-8")).trim();
    }
  }

  return "You are a routing model. Return strict JSON only.";
}

const LLM_ROUTE_CLASSIFIER: DuckAgentConfig = {
  name: "duck-router-classifier",
  description: "Route user input to duck skill and execution chain",
  tools: [],
  model: undefined,
  systemPrompt: [
    readBundledRouterPrompt(),
    "",
    "Return ONLY JSON (no prose, no markdown) with this shape:",
    '{"intent":"review|debug|explain|teach|design|triage","skill":"duck-review|duck-debug|duck-explain|duck-teach|duck-design|duck-triage","agent":"duck-reviewer|duck-investigator|duck-builder|duck-adversary|duck-dry|duck-simple","executionChain":["duck-reviewer|duck-investigator|duck-builder|duck-adversary|duck-dry|duck-simple"],"metaChain":["string"],"reason":"string"}',
    "Ensure agent is the first element of executionChain.",
  ].join("\n"),
  filePath: "(bundled-router-prompt)",
  source: "extension",
};

function extractJsonObject(text: string): string | null {
  const trimmed = text.trim();
  if (!trimmed) return null;

  if (trimmed.startsWith("{")) return trimmed;

  const fenceMatch = trimmed.match(/```(?:json)?\s*([\s\S]*?)```/i);
  if (fenceMatch?.[1]) return fenceMatch[1].trim();

  const start = trimmed.indexOf("{");
  const end = trimmed.lastIndexOf("}");
  if (start >= 0 && end > start) return trimmed.slice(start, end + 1);
  return null;
}

function isKnownDuckling(name: string): name is KnownDuckling {
  return ["duck-reviewer", "duck-investigator", "duck-builder", "duck-adversary", "duck-dry", "duck-simple"].includes(name);
}

function coerceLlMRoute(raw: unknown): Exclude<RouteDecision, null> | null {
  if (!raw || typeof raw !== "object") return null;
  const obj = raw as Record<string, unknown>;

  const intent = typeof obj.intent === "string" ? obj.intent : "";
  const skill = typeof obj.skill === "string" ? obj.skill : "";
  const agent = typeof obj.agent === "string" ? obj.agent : "";
  const reason = typeof obj.reason === "string" ? obj.reason : "llm-route";

  const allowedIntents = new Set(["review", "debug", "explain", "teach", "design", "triage"]);
  const allowedSkills = new Set(["duck-review", "duck-debug", "duck-explain", "duck-teach", "duck-design", "duck-triage"]);

  if (!allowedIntents.has(intent) || !allowedSkills.has(skill) || !isKnownDuckling(agent)) return null;

  const executionChainRaw = Array.isArray(obj.executionChain) ? obj.executionChain : [];
  const executionChain = executionChainRaw
    .map((x) => (typeof x === "string" ? x : ""))
    .filter((x): x is KnownDuckling => isKnownDuckling(x));

  const finalChain = executionChain.length > 0 ? executionChain : [agent];
  if (finalChain[0] !== agent) finalChain.unshift(agent);

  const metaChainRaw = Array.isArray(obj.metaChain) ? obj.metaChain : [];
  const metaChain = metaChainRaw.map((x) => (typeof x === "string" ? x : "")).filter(Boolean);

  return {
    intent: intent as Exclude<RouteDecision, null>["intent"],
    skill: skill as Exclude<RouteDecision, null>["skill"],
    agent,
    executionChain: finalChain,
    metaChain: metaChain.length > 0 ? metaChain : finalChain,
    reason,
  };
}

async function llmRoute(text: string, cwd: string): Promise<Exclude<RouteDecision, null> | null> {
  const result = await runDuckAgent(LLM_ROUTE_CLASSIFIER, `User input:\n${text}`, cwd);
  if (result.exitCode !== 0) return null;

  const jsonText = extractJsonObject(result.output || "");
  if (!jsonText) return null;

  try {
    const parsed = JSON.parse(jsonText);
    return coerceLlMRoute(parsed);
  } catch {
    return null;
  }
}

export default function duckExtension(pi: ExtensionAPI): void {
  const supervisor = new DuckSupervisorStore();

  pi.registerMessageRenderer("duck-user-input", (message, _options, theme) => {
    const content = typeof message.content === "string" ? message.content : "";
    return new Text(`${theme.fg("accent", "❯")} ${content}`, 0, 0);
  });

  pi.registerMessageRenderer("duck-subagent-run", (message, options, theme) => {
    const content = typeof message.content === "string" ? message.content : "";
    const lines = content.split("\n");
    const title = lines[0] ?? "🦆 Subagent";
    const body = stripFencedBackticks(lines.slice(1).join("\n").trim());

    const details =
      (message.details as {
        level?: "info" | "warning" | "error";
        forceExpanded?: boolean;
        nonExpandable?: boolean;
      } | undefined) ?? {};
    const level = details.level ?? "info";
    const forceExpanded = details.forceExpanded === true;
    const nonExpandable = details.nonExpandable === true;
    const titleColor = level === "error" ? "error" : level === "warning" ? "warning" : "toolTitle";

    const collapsedLines = 3;
    const bodyLines = body ? body.split("\n") : [];
    const isCollapsedView = nonExpandable ? false : !(options.expanded || forceExpanded);
    const showCollapsed = isCollapsedView && bodyLines.length > collapsedLines;
    const visibleBody = isCollapsedView ? bodyLines.slice(0, collapsedLines).join("\n") : body;

    const box = new Box(1, 1, (text) => theme.bg("customMessageBg", text));
    const container = new Container();
    container.addChild(new Text(theme.fg(titleColor, theme.bold(title)), 0, 0));

    if (visibleBody) {
      container.addChild(new Spacer(1));
      if (!isCollapsedView) {
        container.addChild(new Markdown(visibleBody, 0, 0, getMarkdownTheme()));
      } else {
        container.addChild(new Text(theme.fg("toolOutput", visibleBody), 0, 0));
      }
    }

    if (isCollapsedView && !nonExpandable) {
      container.addChild(new Spacer(1));
      if (showCollapsed) {
        container.addChild(
          new Text(theme.fg("muted", `... ${bodyLines.length - collapsedLines} more lines (Ctrl+O to expand)`), 0, 0),
        );
      } else {
        container.addChild(new Text(theme.fg("muted", "Ctrl+O to expand"), 0, 0));
      }
    }

    box.addChild(container);
    return box;
  });

  let state: DuckState = { ...DEFAULT_STATE };
  const runtime: DuckStatusRuntime = {};
  let lastRouteMeta = "route=(none) skill=(none) chain=(none)";
  let pendingClarification: { original: string } | null = null;
  let pendingWorkflow:
    | {
        route: Exclude<RouteDecision, null>;
        originalTask: string;
        refinementContext: string;
        interactions: Array<{ role: "user" | "assistant"; text: string }>;
        chain: KnownDuckling[];
        refined: boolean;
      }
    | null = null;
  let pendingWorkflowPrompted = false;
  let pendingFollowup:
    | {
        runId: string;
        route: string;
        skill: string;
        chain: string[];
        baseTask: string;
        interactions: Array<{ role: "user" | "assistant"; text: string }>;
      }
    | null = null;

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
    pendingWorkflow = null;
    pendingWorkflowPrompted = false;
    pendingFollowup = null;
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

  const executeRun = async (run: SupervisorRun, startStep: number, ctx: DuckUiContext) => {
    const results: Array<{ step: number; agent: string; result: DuckInvokeResult }> = [];
    let currentTask = (run.currentTask || run.task || "").trim();

    for (let step = startStep; step <= run.chain.length; step++) {
      const agentName = run.chain[step - 1];
      supervisor.setRunNextStep(run.runId, step, persistSupervisorOp);

      const result = await invokeAgent(agentName, currentTask, ctx);
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
              taskUsed: preview(currentTask, 800),
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

      supervisor.setRunNextStep(run.runId, step + 1, persistSupervisorOp);
      if (result.output?.trim()) {
        currentTask = buildChainedTaskPayload(run.task, result.output);
        supervisor.setRunCurrentTask(run.runId, currentTask, persistSupervisorOp);
      }
    }

    return { paused: false, results };
  };

  const finalizeRun = (
    run: SupervisorRun,
    results: Array<{ step: number; agent: string; result: DuckInvokeResult }>,
    ctx: DuckUiContext,
  ) => {
    const succeeded = results.filter((r) => r.result.ok);
    const failed = results.filter((r) => !r.result.ok);
    const finalOutput = succeeded.at(-1)?.result.output?.trim() || "";

    supervisor.setRunState(run.runId, failed.length > 0 ? "failed" : "completed", persistSupervisorOp);

    const failedLines = failed.map(
      (r) => `- ❌ step ${r.step} ${r.agent} (exit ${r.result.exitCode}${r.result.stderr ? `: ${r.result.stderr}` : ""})`,
    );

    const responseSections = [
      ...(failedLines.length > 0 ? ["Failures:", ...failedLines, ""] : []),
      finalOutput ? finalOutput : "(no final output)",
    ];

    sendRunBlock(
      pi,
      `Subagent response (${run.runId})`,
      responseSections.join("\n"),
      failed.length > 0 ? "warning" : "info",
      {
        forceExpanded: true,
        helperText: [failed.length > 0 ? "inspect failures; then choose next step" : "reply to continue run context · /duck close-run"],
      },
      ctx,
    );

    const priorFollowup = pendingFollowup?.interactions ?? [];
    pendingFollowup = {
      runId: run.runId,
      route: run.route ?? "manual",
      skill: run.skill ?? "direct-duckling",
      chain: [...run.chain],
      baseTask: run.task,
      interactions: [
        ...priorFollowup.slice(-19),
        { role: "assistant", text: preview(finalOutput || "(no final output)", 1600) },
      ],
    };

    runtime.activeSkill = undefined;
    refreshStatus(ctx);
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
      const execution = await executeRun(run, run.nextStep, ctx);
      if (execution.paused) return;
      finalizeRun(run, execution.results, ctx);
    } finally {
      runtime.activeSkill = undefined;
      refreshStatus(ctx);
    }
  };

  const invokeRouteChain = async (route: Exclude<RouteDecision, null>, task: string, ctx: DuckUiContext) => {
    const chain = dedupeChain(route.executionChain.length > 0 ? route.executionChain : [route.agent]);

    runtime.activeSkill = route.skill;
    refreshStatus(ctx);
    pendingWorkflow = {
      route,
      originalTask: task,
      refinementContext: "",
      interactions: [],
      chain,
      refined: false,
    };
    pendingFollowup = null;
    pendingWorkflowPrompted = false;
    runtime.awaitingProceed = true;
    refreshStatus(ctx);

    const kickoff = [
      `${route.skill}, then wait /duck proceed.`,
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
        helperText: ["/duck proceed [summary] · /duck refine [--replace] <text> · /duck cancel"],
        notifyHelper: true,
      },
      ctx,
    );
    return;
  };

  pi.on("session_start", async (_event, ctx) => {
    const entries = ctx.sessionManager?.getEntries?.();
    const persisted = loadPersistedState(entries);
    if (persisted) state = persisted;
    supervisor.hydrate(entries);
    applyWorkingStyle(ctx);
    refreshStatus(ctx);
  });

  pi.on("message_end", async (event) => {
    if (!pendingWorkflow) return;

    const message = (event as { message?: unknown }).message;
    const role = (message as { role?: unknown } | undefined)?.role;
    if (role !== "assistant" && role !== "user") return;

    const text = extractMessageText(message);
    if (!text) return;
    if (role === "user" && text.startsWith("/")) return;

    const kickoffPrefix = `${pendingWorkflow.route.skill}, then wait /duck proceed.`;
    if (role === "user" && text.startsWith(kickoffPrefix)) return;

    pendingWorkflow.interactions.push({ role, text: preview(text, 1600) });
    if (pendingWorkflow.interactions.length > 20) {
      pendingWorkflow.interactions = pendingWorkflow.interactions.slice(-20);
    }
  });

  pi.on("input", async (event, ctx) => {
    const text = event.text ?? "";
    if (!state.enabled || !state.ambientMode) return { action: "continue" };
    if (event.source === "extension") return { action: "continue" };
    if (!text.trim() || text.trim().startsWith("/")) return { action: "continue" };

    if (pendingWorkflow) {
      if (!pendingWorkflowPrompted) {
        sendRunBlock(
          pi,
          "Workflow pending",
          "",
          "info",
          {
            nonExpandable: true,
            helperText: ["continue chatting with the skill, or /duck proceed · /duck refine · /duck cancel"],
            notifyHelper: true,
          },
          ctx,
        );
        pendingWorkflowPrompted = true;
      }
      return { action: "continue" };
    }

    if (text.trim().toLowerCase() === "quack") {
      const line = buildStatusLine(state, runtime) ?? "🦆 off";
      ctx.ui.notify(`${line}\n${lastRouteMeta}`, "info");
      return { action: "handled" };
    }

    if (pendingFollowup) {
      const userText = text.trim();
      if (ctx.ui.confirm) {
        const useFollowup = await ctx.ui.confirm(
          `Continue run ${pendingFollowup.runId}?`,
          "Use this message as follow-up context for the last subagent run?",
        );
        if (!useFollowup) {
          pendingFollowup = null;
          ctx.ui.notify("Run follow-up closed. Routing this as a new request.", "info");
        } else {
          sendUserInline(pi, userText);
          await continueRunFollowup(userText, ctx);
          return { action: "handled" };
        }
      } else {
        sendUserInline(pi, userText);
        await continueRunFollowup(userText, ctx);
        return { action: "handled" };
      }
    }

    if (pendingClarification) {
      const original = pendingClarification.original;
      const clarification = text.trim();
      const combined = `${original}\n\nClarification: ${clarification}`;
      pendingClarification = null;

      sendUserInline(pi, buildClarifiedTaskPayload(original, clarification, 1200));

      runtime.routing = true;
      refreshStatus(ctx);
      let route: RouteDecision = null;
      try {
        route = await withWorking(ctx, "Routing…", async () => llmRoute(combined, ctx.cwd));
      } finally {
        runtime.routing = false;
        refreshStatus(ctx);
      }
      if (!route) {
        pendingClarification = { original };
        lastRouteMeta = "route=clarify skill=(pending) chain=(pending)";
        ctx.ui.notify(UNRECOGNIZED_CLARIFY_QUESTION, "info");
        return { action: "handled" };
      }

      lastRouteMeta = routeMetaLine(route);
      const taskPayload = buildClarifiedTaskPayload(original, clarification);
      await invokeRouteChain(route, taskPayload, ctx);
      return { action: "handled" };
    }

    sendUserInline(pi, text.trim());
    runtime.routing = true;
    refreshStatus(ctx);
    let route: RouteDecision = null;
    try {
      route = await withWorking(ctx, "Routing…", async () => llmRoute(text, ctx.cwd));
    } finally {
      runtime.routing = false;
      refreshStatus(ctx);
    }

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

  const continueRunFollowup = async (userReply: string, ctx: DuckUiContext) => {
    if (!pendingFollowup) {
      ctx.ui.notify("No active run follow-up. Start one by finishing a chain response.", "warning");
      return;
    }

    pendingFollowup.interactions.push({ role: "user", text: preview(userReply, 1600) });
    if (pendingFollowup.interactions.length > 20) {
      pendingFollowup.interactions = pendingFollowup.interactions.slice(-20);
    }

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
    pendingFollowup = null;
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

    pendingWorkflow = null;
    pendingWorkflowPrompted = false;
    runtime.awaitingProceed = false;
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
      ctx.ui.notify("Usage: /duck refine [--replace] <text>", "warning");
      return;
    }

    if (raw === "--replace") {
      ctx.ui.notify("Usage: /duck refine --replace <text>", "warning");
      return;
    }

    if (raw.startsWith("--replace ")) {
      const replacement = raw.slice("--replace ".length).trim();
      if (!replacement) {
        ctx.ui.notify("Usage: /duck refine --replace <text>", "warning");
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
    pendingWorkflow = null;
    pendingWorkflowPrompted = false;
    pendingFollowup = null;
    runtime.awaitingProceed = false;
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
      ctx.ui.notify("Usage: /duck reply <requestId> <decision> [notes]", "warning");
      return;
    }

    const firstSpace = raw.indexOf(" ");
    if (firstSpace < 0) {
      ctx.ui.notify("Usage: /duck reply <requestId> <decision> [notes]", "warning");
      return;
    }

    const requestId = raw.slice(0, firstSpace).trim();
    const remainder = raw.slice(firstSpace + 1).trim();
    if (!remainder) {
      ctx.ui.notify("Usage: /duck reply <requestId> <decision> [notes]", "warning");
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
        { helperText: ["optional: /duck route-preview"] },
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

      const execution = await executeRun(refreshed, refreshed.nextStep, ctx);
      if (execution.paused) return;
      finalizeRun(refreshed, execution.results, ctx);
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

    const execution = await executeRun(refreshed, refreshed.nextStep, ctx);
    if (execution.paused) return;
    finalizeRun(refreshed, execution.results, ctx);
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
