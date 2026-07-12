import { discoverDuckAgents } from "./agents.ts";
import { createDuckEngine, type DuckEngine } from "./engine/index.ts";
import { loadBundledPolicyText } from "./policy.ts";
import type { DuckState } from "./state.ts";

function truncateOutput(text: string, maxChars = 3000): string {
  if (text.length <= maxChars) return text;
  return `${text.slice(0, maxChars)}\n\n[truncated ${text.length - maxChars} chars]`;
}

export type DuckInvokeContext = {
  ui: {
    notify(message: string, level?: "info" | "warning" | "error"): void;
  };
  cwd: string;
};

export type DuckInvokeResult = {
  ok: boolean;
  output: string;
  exitCode: number;
  stderr: string;
  terminalStatus?: "completed" | "failed" | "stopped";
  agentId?: string;
};

export type DuckInvokeMeta = {
  runId: string;
  step: number;
  agent: string;
};

type CreateInvokeAgentDeps = {
  getState(): DuckState;
  persistState(): void;
  refreshStatus(ctx: DuckInvokeContext): void;
  engine?: DuckEngine;
};

export function createInvokeAgent(deps: CreateInvokeAgentDeps) {
  const engine = deps.engine ?? createDuckEngine();

  return async (
    agentName: string,
    task: string,
    ctx: DuckInvokeContext,
    meta?: DuckInvokeMeta,
  ): Promise<DuckInvokeResult> => {
    const discovery = discoverDuckAgents();
    const agent = discovery.agents.find((a) => a.name === agentName);

    if (!agent) {
      const available = discovery.agents.map((a) => a.name).join(", ") || "(none)";
      ctx.ui.notify(`Unknown duck agent: ${agentName}. Available: ${available}`, "error");
      return { ok: false, output: "", exitCode: 1, stderr: `Unknown duck agent: ${agentName}` };
    }

    if (!task.trim()) {
      ctx.ui.notify(`Missing task. Usage: /${agentName} <task>`, "warning");
      return { ok: false, output: "", exitCode: 1, stderr: "Missing task" };
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

    try {
      const result = await engine.spawn({
        runId: meta?.runId ?? `manual_${Date.now().toString(36)}_${Math.random().toString(36).slice(2, 8)}`,
        step: meta?.step ?? 1,
        agent: meta?.agent ?? agent.name,
        prompt: task,
        cwd: ctx.cwd,
        policyText,
      });

      if (result.exitCode !== 0) {
        ctx.ui.notify(
          `${agent.name} failed (exit ${result.exitCode}). ${result.stderr || "No stderr output."}`,
          "error",
        );
        return {
          ok: false,
          output: result.output,
          exitCode: result.exitCode,
          stderr: result.stderr,
          terminalStatus: result.terminalStatus,
        };
      }

      const output = result.output || "(no output)";
      return {
        ok: true,
        output: truncateOutput(output, 12000),
        exitCode: result.exitCode,
        stderr: result.stderr,
        terminalStatus: result.terminalStatus,
        agentId: result.agentId,
      };
    } finally {
      state.activeSubagent = undefined;
      deps.persistState();
      deps.refreshStatus(ctx);
    }
  };
}
