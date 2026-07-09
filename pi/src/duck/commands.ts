import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { KNOWN_DUCKLINGS } from "./agents.ts";
import { UNRECOGNIZED_CLARIFY_QUESTION, type RouteDecision } from "./routing.ts";
import { statusText } from "./status.ts";
import type { DuckState } from "./state.ts";

type CommandContext = {
  ui: {
    notify(message: string, level?: "info" | "warning" | "error"): void;
  };
};

type RegisterDuckCommandsDeps = {
  getState(): DuckState;
  getStatusDetails?(): string[];
  persistState(): void;
  refreshStatus(ctx: CommandContext): void;
  reset(ctx: CommandContext): void;
  invokeAgent(
    agentName: string,
    task: string,
    ctx: CommandContext,
  ): Promise<{ ok: boolean; output: string; exitCode: number; stderr: string }>;
  invokeSupervisorRun(agentName: string, task: string, ctx: CommandContext): Promise<void>;
  previewRoute(input: string, ctx: CommandContext & { cwd: string }): Promise<RouteDecision>;
  proceedWorkflow(args: string, ctx: CommandContext & { cwd: string }): Promise<void>;
  refineWorkflow(args: string, ctx: CommandContext): Promise<void>;
  cancelWorkflow(ctx: CommandContext): Promise<void>;
  listPendingRequests(ctx: CommandContext): Promise<void>;
  listRuns(ctx: CommandContext): Promise<void>;
  replyToRequest(args: string, ctx: CommandContext): Promise<void>;
  resumeRun(args: string, ctx: CommandContext): Promise<void>;
  continueRunFollowup(args: string, ctx: CommandContext): Promise<void>;
  closeRunFollowup(ctx: CommandContext): Promise<void>;
};

function parseDuckCommandArgs(args: string | undefined): string[] {
  return (args ?? "")
    .trim()
    .split(/\s+/)
    .filter(Boolean);
}

export function registerDuckCommands(pi: ExtensionAPI, deps: RegisterDuckCommandsDeps): void {
  pi.registerCommand("duck", {
    description: "Duck controls: /duck help|status|reset|on|off|policy|mode|route",
    handler: async (args, ctx) => {
      const tokens = parseDuckCommandArgs(args);
      const command = tokens[0] ?? "status";
      const state = deps.getState();

      switch (command) {
        case "help": {
          ctx.ui.notify(
            [
              "Duck commands",
              "- /duck status|reset|on|off|policy on|off|mode on|off|route <text>",
              "- /duck proceed [summary] · /duck refine [--replace] <text> · /duck cancel",
              "- /duck route <text> · /duck route-preview <text>",
              "- /duck pending · /duck runs · /duck reply <id> <continue|stop|retry-later> [notes]",
              "- /duck resume <runId> [step]",
              "- /duck followup <text> · /duck close-run",
              "Direct ducklings: /duck-<agent>",
            ].join("\n"),
            "info",
          );
          return;
        }
        case "status": {
          const base = await statusText(state);
          const extra = deps.getStatusDetails?.() ?? [];
          ctx.ui.notify(extra.length > 0 ? `${base}\n${extra.join("\n")}` : base, "info");
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
          const sub = tokens[1];
          const input = tokens.slice(sub === "preview" ? 2 : 1).join(" ").trim();
          if (!input) {
            ctx.ui.notify(sub === "preview" ? "Usage: /duck route preview <text>" : "Usage: /duck route <text>", "warning");
            return;
          }

          const route = await deps.previewRoute(input, ctx as CommandContext & { cwd: string });
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
        case "route-preview": {
          const input = tokens.slice(1).join(" ").trim();
          if (!input) {
            ctx.ui.notify("Usage: /duck route-preview <text>", "warning");
            return;
          }
          const route = await deps.previewRoute(input, ctx as CommandContext & { cwd: string });
          if (!route) {
            ctx.ui.notify(`Route: clarify\nQuestion: ${UNRECOGNIZED_CLARIFY_QUESTION}`, "info");
            return;
          }
          ctx.ui.notify(
            [
              "Duck route preview",
              `route_source=llm`,
              `intent=${route.intent}`,
              `skill=${route.skill}`,
              `chain=${route.executionChain.join(" -> ")}`,
              `reason=${route.reason}`,
              `input=${input}`,
            ].join("\n"),
            "info",
          );
          return;
        }
        case "proceed": {
          await deps.proceedWorkflow(tokens.slice(1).join(" ").trim(), ctx as CommandContext & { cwd: string });
          return;
        }
        case "refine": {
          await deps.refineWorkflow(tokens.slice(1).join(" ").trim(), ctx);
          return;
        }
        case "cancel": {
          await deps.cancelWorkflow(ctx);
          return;
        }
        case "pending": {
          await deps.listPendingRequests(ctx);
          return;
        }
        case "runs": {
          await deps.listRuns(ctx);
          return;
        }
        case "reply": {
          await deps.replyToRequest(tokens.slice(1).join(" ").trim(), ctx);
          return;
        }
        case "resume": {
          await deps.resumeRun(tokens.slice(1).join(" ").trim(), ctx);
          return;
        }
        case "followup": {
          const text = tokens.slice(1).join(" ").trim();
          if (!text) {
            ctx.ui.notify("Usage: /duck followup <text>", "warning");
            return;
          }
          await deps.continueRunFollowup(text, ctx);
          return;
        }
        case "close-run": {
          await deps.closeRunFollowup(ctx);
          return;
        }
        default: {
          ctx.ui.notify("Unknown duck command. Use: /duck help", "warning");
        }
      }
    },
  });

  for (const agentName of KNOWN_DUCKLINGS) {
    pi.registerCommand(agentName, {
      description: `Invoke ${agentName}. Usage: /${agentName} <task>`,
      handler: async (args, ctx) => {
        const task = (args ?? "").trim();
        if (!task) {
          await deps.invokeAgent(agentName, task, ctx);
          return;
        }
        await deps.invokeSupervisorRun(agentName, task, ctx);
      },
    });
  }
}
