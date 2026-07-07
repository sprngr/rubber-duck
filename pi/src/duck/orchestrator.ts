import { discoverDuckAgents } from "./agents.ts";
import { loadBundledPolicyText } from "./policy.ts";
import { runDuckAgent, truncateOutput } from "./runner.ts";
import type { DuckState } from "./state.ts";

export type DuckInvokeContext = {
  ui: {
    notify(message: string, level?: "info" | "warning" | "error"): void;
  };
  cwd: string;
};

type CreateInvokeAgentDeps = {
  getState(): DuckState;
  persistState(): void;
  refreshStatus(ctx: DuckInvokeContext): void;
};

export function createInvokeAgent(deps: CreateInvokeAgentDeps) {
  return async (agentName: string, task: string, ctx: DuckInvokeContext): Promise<void> => {
    const discovery = discoverDuckAgents();
    const agent = discovery.agents.find((a) => a.name === agentName);

    if (!agent) {
      const available = discovery.agents.map((a) => a.name).join(", ") || "(none)";
      ctx.ui.notify(`Unknown duck agent: ${agentName}. Available: ${available}`, "error");
      return;
    }

    if (!task.trim()) {
      ctx.ui.notify(`Missing task. Usage: /${agentName} <task>`, "warning");
      return;
    }

    let policyText = "";
    const state = deps.getState();
    if (state.policyEnabled) {
      try {
        policyText = await loadBundledPolicyText();
      } catch {
        ctx.ui.notify("Duck policy enabled but pi/AGENTS.md was not found.", "warning");
      }
    }

    state.enabled = true;
    state.activeSubagent = agent.name;
    deps.persistState();
    deps.refreshStatus(ctx);

    ctx.ui.notify(`Running ${agent.name}...`, "info");
    const result = await runDuckAgent(agent, task, ctx.cwd, policyText);

    if (result.exitCode !== 0) {
      ctx.ui.notify(
        `${agent.name} failed (exit ${result.exitCode}). ${result.stderr || "No stderr output."}`,
        "error",
      );
      return;
    }

    const output = truncateOutput(result.output || "(no output)");
    ctx.ui.notify(`${agent.name} complete.\n\n${output}`, "info");
  };
}
