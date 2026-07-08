import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import {
  fallbackRouteAfterClarification,
  routeAmbient,
  UNRECOGNIZED_CLARIFY_QUESTION,
  type KnownDuckling,
  type RouteDecision,
} from "./duck/routing.ts";
import { truncateOutput } from "./duck/runner.ts";
import { executeDuckChain, formatDuckChainSummary, type DuckChainPlan } from "./duck/chain.ts";
import { buildStatusLine, type DuckStatusRuntime } from "./duck/status.ts";
import { createInvokeAgent, type DuckInvokeContext } from "./duck/orchestrator.ts";
import {
  DEFAULT_STATE,
  STATE_ENTRY_TYPE,
  loadPersistedState,
  type DuckState,
} from "./duck/state.ts";
import { registerDuckCommands } from "./duck/commands.ts";

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

export default function duckExtension(pi: ExtensionAPI): void {
  let state: DuckState = { ...DEFAULT_STATE };
  const runtime: DuckStatusRuntime = {};
  let lastRouteMeta = "route=(none) skill=(none) chain=(none)";
  let pendingClarification: { original: string } | null = null;

  const persistState = () => {
    pi.appendEntry(STATE_ENTRY_TYPE, { ...state });
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
      await invokeAgentImpl(agentName, task, ctx);
    } finally {
      runtime.runningAgent = undefined;
      refreshStatus(ctx);
    }
  };

  const invokeRouteChain = async (route: Exclude<RouteDecision, null>, task: string, ctx: DuckUiContext) => {
    const chain = dedupeChain(route.executionChain.length > 0 ? route.executionChain : [route.agent]);
    const plan: DuckChainPlan = {
      steps: chain.map((agentName) => ({
        mode: "single",
        task: {
          agent: agentName,
          task: "{input}\n\nPrevious agent output:\n{previous}",
        },
      })),
    };

    const execution = await executeDuckChain({
      plan,
      inputTask: task,
      invokeAgent,
      ctx,
      continueOnError: true,
    });

    if (execution.failed > 0) {
      ctx.ui.notify(formatDuckChainSummary(execution), "warning");
      return;
    }

    if (execution.lastOutput.trim()) {
      ctx.ui.notify(`Chain final output:\n\n${truncateOutput(execution.lastOutput, 1200)}`, "info");
    }
  };

  pi.on("session_start", async (_event, ctx) => {
    const persisted = loadPersistedState(ctx.sessionManager?.getEntries?.());
    if (persisted) state = persisted;
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
      const combined = `${pendingClarification.original}\n\nClarification: ${text.trim()}`;
      pendingClarification = null;

      const route = routeAmbient(combined) ?? fallbackRouteAfterClarification(combined);
      lastRouteMeta = routeMetaLine(route);

      await invokeRouteChain(route, combined, ctx);
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
  });
}
