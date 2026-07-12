import { discoverDuckAgents } from "../agents.ts";
import type { DuckRunTelemetry } from "./types.ts";

const DEFAULT_MAX_CONCURRENT = 4;

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

export type RunnerTelemetryUpdate = {
  turnCount?: number;
  toolUses?: number;
  tokenInput?: number;
  tokenOutput?: number;
  tokenCacheWrite?: number;
  tokenTotal?: number;
  contextPercent?: number;
  compactionCount?: number;
  activeTools?: string[];
  activityText?: string;
  queuedAt?: string;
  runningAt?: string;
  completedAt?: string;
  failedAt?: string;
  stoppedAt?: string;
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
  getTelemetry(agentId: string): DuckRunTelemetry | undefined;
}

type LocalJob = {
  token: number;
  status: string;
  input: RunnerSpawnInput;
  telemetry: DuckRunTelemetry;
  result?: string;
  error?: string;
};

const localJobs = new Map<string, LocalJob>();

function maxConcurrentLocalJobs(): number {
  return positiveIntFromEnv("DUCK_MAX_CONCURRENT", DEFAULT_MAX_CONCURRENT);
}

function countRunningLocalJobs(): number {
  let count = 0;
  for (const job of localJobs.values()) {
    if (job.status === "running") count += 1;
  }
  return count;
}

function startQueuedLocalJob(agentId: string, job: LocalJob): void {
  localJobs.set(agentId, {
    ...job,
    status: "running",
    telemetry: applyTelemetryUpdate(job.telemetry, {
      runningAt: nowIso(),
      activityText: "running",
    }),
  });
  void runLocalJob(agentId, job.input, job.token);
}

function pumpLocalQueue(): void {
  let capacity = Math.max(0, maxConcurrentLocalJobs() - countRunningLocalJobs());
  if (capacity <= 0) return;

  for (const [agentId, job] of localJobs.entries()) {
    if (capacity <= 0) break;
    if (job.status !== "queued") continue;
    startQueuedLocalJob(agentId, job);
    capacity -= 1;
  }
}

function nowIso(): string {
  return new Date().toISOString();
}

// Internal test seam: used by smoke-check for contract assertions.
// Not part of stable extension API surface.
export function createInitialTelemetry(): DuckRunTelemetry {
  return {
    // NaN means "not authoritatively sampled yet".
    turnCount: Number.NaN,
    toolUses: Number.NaN,
    tokenInput: Number.NaN,
    tokenOutput: Number.NaN,
    tokenCacheWrite: Number.NaN,
    tokenTotal: Number.NaN,
    compactionCount: Number.NaN,
    activeTools: [],
    timestamps: {
      queuedAt: nowIso(),
    },
  };
}

// Internal test seam: deterministic queue transition helper for smoke-check.
// Not part of stable extension API surface.
export function simulateQueuePump(statuses: Array<"queued" | "running">, maxConcurrent: number): Array<"queued" | "running"> {
  let running = statuses.filter((s) => s === "running").length;
  return statuses.map((status) => {
    if (status !== "queued") return status;
    if (running < maxConcurrent) {
      running += 1;
      return "running";
    }
    return "queued";
  });
}

function applyTelemetryUpdate(base: DuckRunTelemetry, update: RunnerTelemetryUpdate): DuckRunTelemetry {
  return {
    ...base,
    turnCount: update.turnCount ?? base.turnCount,
    toolUses: update.toolUses ?? base.toolUses,
    tokenInput: update.tokenInput ?? base.tokenInput,
    tokenOutput: update.tokenOutput ?? base.tokenOutput,
    tokenCacheWrite: update.tokenCacheWrite ?? base.tokenCacheWrite,
    tokenTotal: update.tokenTotal ?? base.tokenTotal,
    contextPercent: update.contextPercent ?? base.contextPercent,
    compactionCount: update.compactionCount ?? base.compactionCount,
    activeTools: update.activeTools ?? base.activeTools,
    activityText: update.activityText ?? base.activityText,
    timestamps: {
      ...base.timestamps,
      queuedAt: update.queuedAt ?? base.timestamps.queuedAt,
      runningAt: update.runningAt ?? base.timestamps.runningAt,
      completedAt: update.completedAt ?? base.timestamps.completedAt,
      failedAt: update.failedAt ?? base.timestamps.failedAt,
      stoppedAt: update.stoppedAt ?? base.timestamps.stoppedAt,
    },
  };
}

function parseNumber(value: unknown): number | undefined {
  if (typeof value !== "number" || !Number.isFinite(value)) return undefined;
  return value;
}

function telemetryFromEvent(event: unknown): RunnerTelemetryUpdate {
  if (!event || typeof event !== "object") return {};
  const evt = event as {
    type?: unknown;
    usage?: unknown;
    contextUsage?: unknown;
    compactionCount?: unknown;
    toolName?: unknown;
    tools?: unknown;
    turnCount?: unknown;
    message?: unknown;
  };

  const update: RunnerTelemetryUpdate = {};
  const type = typeof evt.type === "string" ? evt.type : "";

  const usage = evt.usage as Record<string, unknown> | undefined;
  if (usage) {
    const input = parseNumber(usage.input) ?? parseNumber(usage.inputTokens);
    const output = parseNumber(usage.output) ?? parseNumber(usage.outputTokens);
    const cacheWrite = parseNumber(usage.cacheWrite) ?? parseNumber(usage.cacheWriteTokens);
    const total = parseNumber(usage.total);

    if (input !== undefined) update.tokenInput = input;
    if (output !== undefined) update.tokenOutput = output;
    if (cacheWrite !== undefined) update.tokenCacheWrite = cacheWrite;
    if (total !== undefined) {
      update.tokenTotal = total;
    } else if (input !== undefined || output !== undefined || cacheWrite !== undefined) {
      update.tokenTotal = (input ?? 0) + (output ?? 0) + (cacheWrite ?? 0);
    }
  }

  const contextUsage = evt.contextUsage as Record<string, unknown> | undefined;
  if (contextUsage) {
    const percent = parseNumber(contextUsage.percent);
    if (percent !== undefined) update.contextPercent = percent;
  }

  const compact = parseNumber(evt.compactionCount);
  if (compact !== undefined) update.compactionCount = compact;

  const turns = parseNumber(evt.turnCount);
  if (turns !== undefined) update.turnCount = turns;

  if (type === "message_end") {
    const message = evt.message as { role?: unknown } | undefined;
    if (message?.role === "assistant") {
      update.activityText = "thinking";
    }
  }

  return update;
}

function deriveActiveTools(base: string[], event: { type?: string; toolName?: unknown }): string[] {
  const type = event.type ?? "";
  const toolName = typeof event.toolName === "string" ? event.toolName.trim() : "";
  if (!toolName) {
    if (type === "tool_execution_end") return [];
    return base;
  }

  if (type === "tool_execution_start") {
    return base.includes(toolName) ? base : [...base, toolName];
  }
  if (type === "tool_execution_end") {
    return base.filter((name) => name !== toolName);
  }
  return base;
}

function describeActiveTools(activeTools: string[]): string | undefined {
  if (activeTools.length === 0) return undefined;
  if (activeTools.length > 1) return `running ${activeTools.length} tools`;

  const one = activeTools[0] ?? "";
  switch (one) {
    case "read":
      return "reading";
    case "grep":
    case "find":
    case "ls":
      return "searching";
    case "edit":
    case "write":
      return "editing";
    case "bash":
      return "running bash";
    default:
      return `using ${one}`;
  }
}

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

    const beforeRun = localJobs.get(agentId);
    if (beforeRun && beforeRun.token === token) {
      localJobs.set(agentId, {
        ...beforeRun,
        telemetry: applyTelemetryUpdate(beforeRun.telemetry, {
          runningAt: nowIso(),
          activityText: "running",
        }),
      });
    }

    let finalText = "";
    const s = session as {
      subscribe(listener: (event: unknown) => void): () => void;
      prompt(text: string): Promise<void>;
      dispose?(): void;
    };

    const unsubscribe = s.subscribe((event) => {
      const evt = event as { type?: string; toolName?: unknown; message?: unknown };
      const sampled = telemetryFromEvent(event);
      if (Object.keys(sampled).length > 0) {
        const current = localJobs.get(agentId);
        if (current && current.token === token) {
          const nextActiveTools = deriveActiveTools(current.telemetry.activeTools ?? [], evt);
          const activeText = describeActiveTools(nextActiveTools);
          localJobs.set(agentId, {
            ...current,
            telemetry: applyTelemetryUpdate(current.telemetry, {
              ...sampled,
              activeTools: nextActiveTools,
              activityText: activeText ?? sampled.activityText ?? "running",
            }),
          });
        }
      }

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
      localJobs.set(agentId, {
        ...current,
        status: "completed",
        result: finalText,
        error: undefined,
        telemetry: applyTelemetryUpdate(current.telemetry, {
          completedAt: nowIso(),
          activityText: "done",
        }),
      });
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
      telemetry: applyTelemetryUpdate(current.telemetry, {
        failedAt: nowIso(),
        activityText: "error",
      }),
    });
  } finally {
    pumpLocalQueue();
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
      localJobs.set(agentId, {
        token,
        input,
        status: "queued",
        telemetry: applyTelemetryUpdate(createInitialTelemetry(), {
          activityText: "queued",
        }),
      });
      pumpLocalQueue();
      return { agentId };
    },
    async poll(agentId: string): Promise<RunnerPollResult> {
      const job = localJobs.get(agentId);
      if (!job) return { done: false };
      if (!isTerminal(job.status)) return { done: false, status: job.status };
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
        telemetry: applyTelemetryUpdate(current.telemetry, {
          runningAt: nowIso(),
          activityText: "steered-retry",
          activeTools: [],
        }),
        result: undefined,
        error: undefined,
      });
      void runLocalJob(agentId, nextInput, nextToken);
      return { ok: true };
    },
    getTelemetry(agentId: string): DuckRunTelemetry | undefined {
      return localJobs.get(agentId)?.telemetry;
    },
  };
}

export async function resolveSessionRunner(): Promise<DuckSessionRunner> {
  return createLocalRunner();
}
