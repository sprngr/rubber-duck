import * as fs from "node:fs";
import * as path from "node:path";
import { fileURLToPath } from "node:url";
import {
  positiveIntFromEnv,
  resolveSessionRunner,
  sleep,
  type DuckSessionRunner,
} from "./engine/session-runner.ts";
import type { KnownDuckling, RouteDecision } from "./routing.ts";
const DEFAULT_TIMEOUT_MS = 30_000;
const DEFAULT_POLL_MS = 120;
const ROUTER_AGENT_TYPE = "general-purpose";

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

const LLM_ROUTE_CLASSIFIER_PROMPT = [
    readBundledRouterPrompt(),
    "",
    "Return ONLY JSON (no prose, no markdown) with this shape:",
    '{"intent":"review|debug|explain|teach|design|triage","skill":"duck-review|duck-debug|duck-explain|duck-teach|duck-design|duck-triage","agent":"duck-reviewer|duck-investigator|duck-builder|duck-adversary|duck-dry|duck-simple","executionChain":["duck-reviewer|duck-investigator|duck-builder|duck-adversary|duck-dry|duck-simple"],"metaChain":["string"],"reason":"string"}',
    "Ensure agent is the first element of executionChain.",
  ].join("\n");

async function collectClassifierOutput(
  runner: DuckSessionRunner,
  agentId: string,
  timeoutMs: number,
  pollMs: number,
): Promise<string | null> {
  const startedAt = Date.now();

  while (Date.now() - startedAt < timeoutMs) {
    const record = await runner.poll(agentId);
    if (record.done) {
      if (record.status !== "completed" && record.status !== "steered") return null;
      return (record.result ?? "").trim() || null;
    }
    await sleep(pollMs);
  }

  return null;
}

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

export async function llmRoute(text: string, _cwd: string): Promise<Exclude<RouteDecision, null> | null> {
  const runner = await resolveSessionRunner();

  const prompt = [
    LLM_ROUTE_CLASSIFIER_PROMPT,
    "",
    "User input:",
    text,
  ].join("\n");

  let agentId = "";
  try {
    ({ agentId } = await runner.spawn({
      agent: ROUTER_AGENT_TYPE,
      prompt,
      cwd: _cwd,
      description: "Route input",
    }));
  } catch {
    return null;
  }

  const timeoutMs = positiveIntFromEnv("DUCK_AGENT_TIMEOUT_MS", DEFAULT_TIMEOUT_MS);
  const pollMs = positiveIntFromEnv("DUCK_SUBAGENT_POLL_MS", DEFAULT_POLL_MS);
  const output = await collectClassifierOutput(runner, agentId, timeoutMs, pollMs);

  if (!output) return null;

  const jsonText = extractJsonObject(output || "");
  if (!jsonText) return null;

  try {
    const parsed = JSON.parse(jsonText);
    return coerceLlMRoute(parsed);
  } catch {
    return null;
  }
}
