import { discoverDuckAgents } from "./agents.ts";
import { bundledPolicyExists, bundledPolicyPath } from "./policy.ts";
import type { DuckState } from "./state.ts";

export function buildStatusLine(state: DuckState): string | undefined {
  if (!state.enabled) return undefined;
  const active = state.activeSubagent ? ` (${state.activeSubagent})` : "";
  const flags: string[] = [];
  if (!state.policyEnabled) flags.push("policy:off");
  if (!state.ambientMode) flags.push("ambient:off");
  const suffix = flags.length > 0 ? ` ${flags.join(" ")}` : "";
  return `🦆${active}${suffix}`;
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
