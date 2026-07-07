import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { routeAmbient } from "./duck/routing.ts";
import { buildStatusLine, statusText } from "./duck/status.ts";
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

function applyStatus(ctx: DuckUiContext, state: DuckState): void {
  ctx.ui.setStatus("duck", buildStatusLine(state));
}

export default function duckExtension(pi: ExtensionAPI): void {
  let state: DuckState = { ...DEFAULT_STATE };

  const persistState = () => {
    pi.appendEntry(STATE_ENTRY_TYPE, { ...state });
  };

  const refreshStatus = (ctx: DuckUiContext) => {
    applyStatus(ctx, state);
  };

  const reset = (ctx: DuckUiContext) => {
    state = { ...DEFAULT_STATE };
    persistState();
    refreshStatus(ctx);
  };

  const invokeAgent = createInvokeAgent({
    getState: () => state,
    persistState,
    refreshStatus,
  });

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
      const meta = await statusText(state);
      ctx.ui.notify(`🦆 ambient router active\n${meta}`, "info");
      return { action: "handled" };
    }

    const route = routeAmbient(text);
    if (!route) {
      return { action: "continue" };
    }

    await invokeAgent(route.agent, text, ctx);
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
