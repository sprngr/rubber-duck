import { discoverDuckAgents } from "./agents.ts";
import { bundledPolicyExists, bundledPolicyPath } from "./policy.ts";
import type { DuckState } from "./state.ts";

export type DuckStatusRuntime = {
  routing?: boolean;
  activeSkill?: string;
  runningAgent?: string;
  awaitingProceed?: boolean;
};

function presentAgentName(name: string): string {
  return name.replace(/^duck-/, "");
}

export function buildStatusLine(state: DuckState, runtime?: DuckStatusRuntime): string | undefined {
  if (!state.enabled) return undefined;

  const runtimeParts: string[] = [];
  if (runtime?.routing) runtimeParts.push("routing…");
  if (runtime?.activeSkill) runtimeParts.push(`skill ${runtime.activeSkill.replace(/^duck-/, "")}`);
  if (runtime?.runningAgent) runtimeParts.push(`running ${presentAgentName(runtime.runningAgent)}`);
  if (runtime?.awaitingProceed) runtimeParts.push("awaiting /duck proceed");

  const core = runtimeParts.length > 0
    ? runtimeParts.join(" · ")
    : state.activeSubagent
      ? presentAgentName(state.activeSubagent)
      : "";

  const flags: string[] = [];
  if (!state.ambientMode) flags.push("ambient off");
  if (!state.policyEnabled) flags.push("policy off");

  const parts = ["🦆"];
  if (core) parts.push(core);
  if (flags.length > 0) parts.push(flags.join(" · "));
  return parts.join(" ");
}

export async function statusText(state: DuckState): Promise<string> {
  const discovery = discoverDuckAgents();
  const names = discovery.agents.map((a) => a.name).join(", ") || "(none)";

  const policyPath = bundledPolicyPath();
  const policyAvailable = await bundledPolicyExists();

  return [
    "Duck extension status",
    `- enabled: ${state.enabled ? "on" : "off"}`,
    `- active subagent: ${state.activeSubagent ?? "(none)"}`,
    `- ambient mode: ${state.ambientMode ? "on" : "off"}`,
    `- policy enabled: ${state.policyEnabled ? "on" : "off"}`,
    `- policy path: ${policyPath}`,
    `- policy file: ${policyAvailable ? "found" : "missing"}`,
    `- agents dir: ${discovery.agentsDir ?? "(not found)"}`,
    `- discovered agents: ${names}`,
  ].join("\n");
}
