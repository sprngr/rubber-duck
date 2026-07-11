import { discoverDuckAgents } from "../agents.ts";

export type RunnerSpawnInput = {
  agent: string;
  prompt: string;
  cwd: string;
  policyText?: string;
  description?: string;
};

export type RunnerSpawnResult = {
  agentId: string;
};

export type RunnerPollResult = {
  done: boolean;
  status?: string;
  result?: string;
  error?: string;
};

export type RunnerSteerResult = {
  ok: boolean;
  reason?: string;
};

export interface DuckSessionRunner {
  name: "local";
  spawn(input: RunnerSpawnInput): Promise<RunnerSpawnResult>;
  poll(agentId: string): Promise<RunnerPollResult>;
  steer(agentId: string, message: string): Promise<RunnerSteerResult>;
}

type LocalJob = {
  token: number;
  status: string;
  input: RunnerSpawnInput;
  result?: string;
  error?: string;
};

const localJobs = new Map<string, LocalJob>();

function makeLocalId(): string {
  return `local_${Date.now().toString(36)}_${Math.random().toString(36).slice(2, 8)}`;
}

function extractTextContent(message: unknown): string {
  if (!message || typeof message !== "object") return "";
  const content = (message as { content?: unknown }).content;
  if (typeof content === "string") return content.trim();
  if (!Array.isArray(content)) return "";

  return content
    .map((part) => {
      if (!part || typeof part !== "object") return "";
      const p = part as { type?: unknown; text?: unknown };
      return p.type === "text" && typeof p.text === "string" ? p.text : "";
    })
    .filter(Boolean)
    .join("\n")
    .trim();
}

function buildLocalPrompt(input: RunnerSpawnInput): string {
  const discovery = discoverDuckAgents();
  const agent = discovery.agents.find((a) => a.name === input.agent);

  const parts: string[] = [];
  if (input.policyText?.trim()) {
    parts.push(`# Extension AGENTS.md policy\n\n${input.policyText.trim()}`);
  }
  if (agent?.systemPrompt?.trim()) {
    parts.push(`# Duck agent prompt (${input.agent})\n\n${agent.systemPrompt.trim()}`);
  }
  parts.push(input.prompt);
  return parts.join("\n\n---\n\n").trim();
}

async function runLocalJob(agentId: string, input: RunnerSpawnInput, token: number): Promise<void> {
  try {
    const sdk = await import("@earendil-works/pi-coding-agent");
    const { createAgentSession, SessionManager } = sdk as {
      createAgentSession: (opts: Record<string, unknown>) => Promise<{ session: unknown }>;
      SessionManager: { inMemory(cwd?: string): unknown };
    };

    const { session } = await createAgentSession({
      cwd: input.cwd,
      sessionManager: SessionManager.inMemory(input.cwd),
    });

    let finalText = "";
    const s = session as {
      subscribe(listener: (event: unknown) => void): () => void;
      prompt(text: string): Promise<void>;
      dispose?(): void;
    };

    const unsubscribe = s.subscribe((event) => {
      const evt = event as { type?: string; message?: unknown };
      if (evt.type !== "message_end") return;
      const message = evt.message as { role?: unknown } | undefined;
      if (message?.role !== "assistant") return;
      const text = extractTextContent(evt.message);
      if (text) finalText = text;
    });

    try {
      await s.prompt(buildLocalPrompt(input));
      const current = localJobs.get(agentId);
      if (!current || current.token !== token) return;
      localJobs.set(agentId, { ...current, status: "completed", result: finalText, error: undefined });
    } finally {
      unsubscribe();
      s.dispose?.();
    }
  } catch (error) {
    const current = localJobs.get(agentId);
    if (!current || current.token !== token) return;
    localJobs.set(agentId, {
      ...current,
      status: "error",
      error: error instanceof Error ? error.message : String(error),
    });
  }
}

function buildSteeredInput(input: RunnerSpawnInput, message: string): RunnerSpawnInput {
  const steerBlock = [
    "Steer update:",
    message.trim(),
    "",
    "Re-run the same task and incorporate this steer update.",
  ].join("\n");

  return {
    ...input,
    prompt: `${input.prompt}\n\n---\n\n${steerBlock}`,
  };
}

export function positiveIntFromEnv(name: string, fallback: number): number {
  const raw = process.env[name];
  if (!raw) return fallback;
  const parsed = Number.parseInt(raw, 10);
  if (!Number.isFinite(parsed) || parsed <= 0) return fallback;
  return parsed;
}

export function isTerminal(status: string): boolean {
  return status === "completed" || status === "steered" || status === "stopped" || status === "aborted" || status === "error";
}

export function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => {
    setTimeout(resolve, ms);
  });
}

async function createLocalRunner(): Promise<DuckSessionRunner> {
  return {
    name: "local",
    async spawn(input: RunnerSpawnInput): Promise<RunnerSpawnResult> {
      const agentId = makeLocalId();
      const token = 1;
      localJobs.set(agentId, { token, input, status: "running" });
      void runLocalJob(agentId, input, token);
      return { agentId };
    },
    async poll(agentId: string): Promise<RunnerPollResult> {
      const job = localJobs.get(agentId);
      if (!job) return { done: false };
      if (!isTerminal(job.status)) return { done: false };
      return {
        done: true,
        status: job.status,
        result: job.result,
        error: job.error,
      };
    },
    async steer(agentId: string, message: string): Promise<RunnerSteerResult> {
      const current = localJobs.get(agentId);
      if (!current) return { ok: false, reason: "agent not found" };
      if (isTerminal(current.status)) return { ok: false, reason: `agent already ${current.status}` };

      const nextToken = current.token + 1;
      const nextInput = buildSteeredInput(current.input, message);
      localJobs.set(agentId, {
        token: nextToken,
        input: nextInput,
        status: "running",
        result: undefined,
        error: undefined,
      });
      void runLocalJob(agentId, nextInput, nextToken);
      return { ok: true };
    },
  };
}

export async function resolveSessionRunner(): Promise<DuckSessionRunner> {
  return createLocalRunner();
}
