import * as fs from "node:fs";
import * as path from "node:path";
import { fileURLToPath } from "node:url";

export type DuckAgentSource = "extension";

export type DuckAgentConfig = {
  name: string;
  description: string;
  tools?: string[];
  model?: string;
  systemPrompt: string;
  filePath: string;
  source: DuckAgentSource;
};

export type DuckAgentDiscovery = {
  agents: DuckAgentConfig[];
  agentsDir: string | null;
};

export const KNOWN_DUCKLINGS = [
  "duck-reviewer",
  "duck-investigator",
  "duck-builder",
  "duck-adversary",
  "duck-dry",
  "duck-simple",
] as const;

function parseFrontmatter(markdown: string): { frontmatter: Record<string, string>; body: string } {
  if (!markdown.startsWith("---\n")) return { frontmatter: {}, body: markdown };

  const end = markdown.indexOf("\n---\n", 4);
  if (end === -1) return { frontmatter: {}, body: markdown };

  const raw = markdown.slice(4, end);
  const body = markdown.slice(end + 5);
  const frontmatter: Record<string, string> = {};

  for (const line of raw.split("\n")) {
    const idx = line.indexOf(":");
    if (idx <= 0) continue;
    const key = line.slice(0, idx).trim();
    const value = line.slice(idx + 1).trim();
    if (!key) continue;
    frontmatter[key] = value;
  }

  return { frontmatter, body };
}

function parseAgentFile(filePath: string): DuckAgentConfig | null {
  let content = "";
  try {
    content = fs.readFileSync(filePath, "utf-8");
  } catch {
    return null;
  }

  const { frontmatter, body } = parseFrontmatter(content);
  const name = frontmatter.name;
  const description = frontmatter.description;

  if (!name || !description) return null;

  const tools = frontmatter.tools
    ?.split(",")
    .map((t) => t.trim())
    .filter(Boolean);

  return {
    name,
    description,
    tools: tools && tools.length > 0 ? tools : undefined,
    model: frontmatter.model,
    systemPrompt: body.trim(),
    filePath,
    source: "extension",
  };
}

function hasDir(p: string): boolean {
  try {
    return fs.statSync(p).isDirectory();
  } catch {
    return false;
  }
}

function extensionAgentsDir(): string | null {
  const here = path.dirname(fileURLToPath(import.meta.url));
  const candidates = [
    path.resolve(here, "../../agents"),
    path.resolve(here, "../../../agents"),
  ];

  for (const candidate of candidates) {
    if (hasDir(candidate)) return candidate;
  }
  return null;
}

function loadAgentsFromDir(agentsDir: string | null): DuckAgentConfig[] {
  if (!agentsDir) return [];

  let entries: fs.Dirent[] = [];
  try {
    entries = fs.readdirSync(agentsDir, { withFileTypes: true });
  } catch {
    return [];
  }

  const agents: DuckAgentConfig[] = [];
  for (const entry of entries) {
    if (!entry.name.endsWith(".md")) continue;
    if (!entry.isFile() && !entry.isSymbolicLink()) continue;

    const parsed = parseAgentFile(path.join(agentsDir, entry.name));
    if (!parsed) continue;
    agents.push(parsed);
  }

  return agents;
}

export function discoverDuckAgents(): DuckAgentDiscovery {
  const agentsDir = extensionAgentsDir();
  const agents = loadAgentsFromDir(agentsDir);

  return {
    agents,
    agentsDir,
  };
}
