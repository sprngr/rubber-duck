import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { KNOWN_DUCKLINGS } from "./agents.ts";
import {
  executeDuckChain,
  formatDuckChainSummary,
  parseDuckChainSpec,
  splitChainAndInput,
} from "./chain.ts";
import { routeAmbient, UNRECOGNIZED_CLARIFY_QUESTION } from "./routing.ts";
import { statusText } from "./status.ts";
import type { DuckState } from "./state.ts";

type CommandContext = {
  ui: {
    notify(message: string, level?: "info" | "warning" | "error"): void;
  };
  cwd: string;
};

type RegisterDuckCommandsDeps = {
  getState(): DuckState;
  persistState(): void;
  refreshStatus(ctx: CommandContext): void;
  reset(ctx: CommandContext): void;
  invokeAgent(
    agentName: string,
    task: string,
    ctx: CommandContext,
  ): Promise<{ ok: boolean; output: string; exitCode: number; stderr: string }>;
};

function firstToken(raw: string): { command: string; remainder: string } {
  const trimmed = raw.trim();
  if (!trimmed) return { command: "status", remainder: "" };
  const idx = trimmed.search(/\s/);
  if (idx < 0) return { command: trimmed, remainder: "" };
  return {
    command: trimmed.slice(0, idx),
    remainder: trimmed.slice(idx).trim(),
  };
}

async function runChainFromRaw(raw: string, ctx: CommandContext, deps: RegisterDuckCommandsDeps): Promise<void> {
  const { chainSpec, inputTask } = splitChainAndInput(raw);
  const parsed = parseDuckChainSpec(chainSpec);

  if (!parsed.plan) {
    ctx.ui.notify(`Invalid chain: ${parsed.error ?? "parse error"}`, "warning");
    return;
  }

  const result = await executeDuckChain({
    plan: parsed.plan,
    inputTask,
    invokeAgent: deps.invokeAgent,
    ctx,
    continueOnError: true,
  });

  ctx.ui.notify(formatDuckChainSummary(result), result.failed > 0 ? "warning" : "info");
}

export function registerDuckCommands(pi: ExtensionAPI, deps: RegisterDuckCommandsDeps): void {
  pi.registerCommand("duck", {
    description: "Duck controls: /duck status|reset|on|off|policy|mode|route|chain",
    handler: async (args, ctx) => {
      const { command, remainder } = firstToken(args ?? "");
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
          const value = firstToken(remainder).command;
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
          const value = firstToken(remainder).command;
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
          const input = remainder.trim();
          if (!input) {
            ctx.ui.notify("Usage: /duck route <text>", "warning");
            return;
          }

          const route = routeAmbient(input);
          if (!route) {
            ctx.ui.notify(`Route: clarify\nQuestion: ${UNRECOGNIZED_CLARIFY_QUESTION}`, "info");
            return;
          }

          const execChain = route.executionChain.join(" > ") || route.agent;
          const metaChain = route.metaChain.join(" > ") || execChain;
          ctx.ui.notify(
            `Route: ${route.intent}\nSkill: ${route.skill}\nExec chain: ${execChain}\nMeta chain: ${metaChain}\nReason: ${route.reason}`,
            "info",
          );
          return;
        }
        case "chain": {
          if (!remainder.trim()) {
            ctx.ui.notify(
              "Usage: /duck chain duck-investigator \"scan\" -> (duck-reviewer \"A\" | duck-simple \"B\")[concurrency=2,failFast] -- global task",
              "warning",
            );
            return;
          }

          await runChainFromRaw(remainder, ctx, deps);
          return;
        }
        default: {
          ctx.ui.notify("Unknown duck command. Use: /duck status|reset|on|off|policy|mode|route|chain", "warning");
        }
      }
    },
  });

  for (const agentName of KNOWN_DUCKLINGS) {
    pi.registerCommand(agentName, {
      description: `Invoke ${agentName}. Usage: /${agentName} <task> (or chain tail with ->)`,
      handler: async (args, ctx) => {
        const raw = (args ?? "").trim();
        if (!raw) {
          await deps.invokeAgent(agentName, "", ctx);
          return;
        }

        if (raw.includes("->")) {
          await runChainFromRaw(`${agentName} ${raw}`.trim(), ctx, deps);
          return;
        }

        await deps.invokeAgent(agentName, raw, ctx);
      },
    });
  }
}
