import * as fs from "node:fs";
import * as path from "node:path";
import { fileURLToPath } from "node:url";
import type { DuckAgentConfig } from "./agents.ts";
import { runDuckAgent } from "./runner.ts";
import type { KnownDuckling, RouteDecision } from "./routing.ts";

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

const LLM_ROUTE_CLASSIFIER: DuckAgentConfig = {
  name: "duck-router-classifier",
  description: "Route user input to duck skill and execution chain",
  tools: [],
  model: undefined,
  systemPrompt: [
    readBundledRouterPrompt(),
    "",
    "Return ONLY JSON (no prose, no markdown) with this shape:",
    '{"intent":"review|debug|explain|teach|design|triage","skill":"duck-review|duck-debug|duck-explain|duck-teach|duck-design|duck-triage","agent":"duck-reviewer|duck-investigator|duck-builder|duck-adversary|duck-dry|duck-simple","executionChain":["duck-reviewer|duck-investigator|duck-builder|duck-adversary|duck-dry|duck-simple"],"metaChain":["string"],"reason":"string"}',
    "Ensure agent is the first element of executionChain.",
  ].join("\n"),
  filePath: "(bundled-router-prompt)",
  source: "extension",
};

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

export async function llmRoute(text: string, cwd: string): Promise<Exclude<RouteDecision, null> | null> {
  const result = await runDuckAgent(LLM_ROUTE_CLASSIFIER, `User input:\n${text}`, cwd);
  if (result.exitCode !== 0) return null;

  const jsonText = extractJsonObject(result.output || "");
  if (!jsonText) return null;

  try {
    const parsed = JSON.parse(jsonText);
    return coerceLlMRoute(parsed);
  } catch {
    return null;
  }
}
