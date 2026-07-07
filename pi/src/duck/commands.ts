import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { KNOWN_DUCKLINGS } from "./agents.ts";
import { routeAmbient } from "./routing.ts";
import { statusText } from "./status.ts";
import type { DuckState } from "./state.ts";

type CommandContext = {
  ui: {
    notify(message: string, level?: "info" | "warning" | "error"): void;
  };
};

type RegisterDuckCommandsDeps = {
  getState(): DuckState;
  persistState(): void;
  refreshStatus(ctx: CommandContext): void;
  reset(ctx: CommandContext): void;
  invokeAgent(agentName: string, task: string, ctx: CommandContext): Promise<void>;
};

function parseDuckCommandArgs(args: string | undefined): string[] {
  return (args ?? "")
    .trim()
    .split(/\s+/)
    .filter(Boolean);
}

export function registerDuckCommands(pi: ExtensionAPI, deps: RegisterDuckCommandsDeps): void {
  pi.registerCommand("duck", {
    description: "Duck controls: /duck status|reset|on|off|policy|mode|route",
    handler: async (args, ctx) => {
      const tokens = parseDuckCommandArgs(args);
      const command = tokens[0] ?? "status";
      const state = deps.getState();

      switch (command) {
        case "status": {
          ctx.ui.notify(await statusText(state), "info");
          return;
        }
        case "reset": {
          deps.reset(ctx);
          ctx.ui.notify("Duck state reset to defaults.", "info");
          return;
        }
        case "on": {
          state.enabled = true;
          deps.persistState();
          deps.refreshStatus(ctx);
          ctx.ui.notify("Duck enabled.", "info");
          return;
        }
        case "off": {
          state.enabled = false;
          deps.persistState();
          deps.refreshStatus(ctx);
          ctx.ui.notify("Duck disabled.", "info");
          return;
        }
        case "policy": {
          const value = tokens[1];
          if (value !== "on" && value !== "off") {
            ctx.ui.notify("Usage: /duck policy on|off", "warning");
            return;
          }
          state.policyEnabled = value === "on";
          deps.persistState();
          deps.refreshStatus(ctx);
          ctx.ui.notify(`Duck AGENTS.md policy ${value}.`, "info");
          return;
        }
        case "mode": {
          const value = tokens[1];
          if (value !== "on" && value !== "off") {
            ctx.ui.notify("Usage: /duck mode on|off", "warning");
            return;
          }
          state.ambientMode = value === "on";
          deps.persistState();
          deps.refreshStatus(ctx);
          ctx.ui.notify(`Duck ambient mode ${value}.`, "info");
          return;
        }
        case "route": {
          const input = tokens.slice(1).join(" ").trim();
          if (!input) {
            ctx.ui.notify("Usage: /duck route <text>", "warning");
            return;
          }

          const route = routeAmbient(input);
          if (!route) {
            ctx.ui.notify("Route: pass-through (no subagent)", "info");
            return;
          }

          ctx.ui.notify(`Route: ${route.agent}\nReason: ${route.reason}`, "info");
          return;
        }
        default: {
          ctx.ui.notify("Unknown duck command. Use: /duck status|reset|on|off|policy|mode|route", "warning");
        }
      }
    },
  });

  for (const agentName of KNOWN_DUCKLINGS) {
    pi.registerCommand(agentName, {
      description: `Invoke ${agentName}. Usage: /${agentName} <task>`,
      handler: async (args, ctx) => {
        const task = (args ?? "").trim();
        await deps.invokeAgent(agentName, task, ctx);
      },
    });
  }
}
