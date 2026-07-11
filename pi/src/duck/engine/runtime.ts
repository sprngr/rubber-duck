import { DuckEngineState } from "./state.ts";
import {
  positiveIntFromEnv,
  sleep,
  resolveSessionRunner,
} from "./session-runner.ts";
import type { DuckEngineSpawnInput, DuckEngineSpawnResult, DuckEngineSteerResult } from "./types.ts";
const DEFAULT_TIMEOUT_MS = 120_000;
const DEFAULT_POLL_MS = 120;

function buildDescription(input: DuckEngineSpawnInput): string {
  const firstLine = input.prompt
    .split("\n")
    .map((line) => line.trim())
    .find(Boolean);
  const summary = firstLine
    ? firstLine.length <= 48
      ? firstLine
      : `${firstLine.slice(0, 47)}…`
    : "task";
  return `${input.agent} r:${input.runId} s:${input.step} · ${summary}`;
}

export type CreateDuckEngineRuntimeDeps = {
  state?: DuckEngineState;
};

export function createDuckEngineRuntime(deps: CreateDuckEngineRuntimeDeps = {}) {
  const state = deps.state ?? new DuckEngineState();

  return {
    state,
    async spawn(input: DuckEngineSpawnInput): Promise<DuckEngineSpawnResult> {
      const runner = await resolveSessionRunner();

      state.upsertRun({ runId: input.runId, step: input.step, agent: input.agent, status: "running" });

      let agentId = "";
      try {
        ({ agentId } = await runner.spawn({
          agent: input.agent,
          prompt: input.prompt,
          cwd: input.cwd,
          policyText: input.policyText,
          description: buildDescription(input),
        }));
      } catch {
        state.patchRun(input.runId, { status: "failed", error: "spawn failed" });
        return {
          ok: false,
          output: "",
          exitCode: 1,
          stderr: "DuckEngine spawn failed",
        };
      }

      state.patchRun(input.runId, { activeAgentId: agentId });

      const timeoutMs = positiveIntFromEnv("DUCK_AGENT_TIMEOUT_MS", DEFAULT_TIMEOUT_MS);
      const pollMs = positiveIntFromEnv("DUCK_SUBAGENT_POLL_MS", DEFAULT_POLL_MS);
      const startedAt = Date.now();

      while (Date.now() - startedAt < timeoutMs) {
        const poll = await runner.poll(agentId);
        if (poll.done) {
          if (poll.status === "completed" || poll.status === "steered") {
            state.patchRun(input.runId, {
              status: "completed",
              output: poll.result ?? "",
              error: undefined,
              activeAgentId: agentId,
            });
            return {
              ok: true,
              output: poll.result ?? "",
              exitCode: 0,
              stderr: "",
              agentId,
            };
          }

          const terminalStatus = poll.status ?? "error";
          const err = poll.error ?? `Subagent terminal status: ${terminalStatus}`;
          state.patchRun(input.runId, {
            status: terminalStatus === "stopped" ? "stopped" : "failed",
            output: poll.result ?? "",
            error: err,
            activeAgentId: agentId,
          });
          return {
            ok: false,
            output: poll.result ?? "",
            exitCode: 1,
            stderr: err,
            agentId,
          };
        }

        await sleep(pollMs);
      }

      state.patchRun(input.runId, {
        status: "failed",
        error: `Timed out after ${timeoutMs}ms waiting for duck engine run`,
        activeAgentId: agentId,
      });
      return {
        ok: false,
        output: "",
        exitCode: 124,
        stderr: `Timed out after ${timeoutMs}ms waiting for duck engine run`,
        agentId,
      };
    },

    async steer(runId: string, message: string): Promise<DuckEngineSteerResult> {
      const run = state.getRun(runId);
      if (!run) return { ok: false, reason: "run not found" };
      if (!run.activeAgentId) return { ok: false, reason: "active agent id missing" };

      const runner = await resolveSessionRunner();
      const result = await runner.steer(run.activeAgentId, message);
      return result.ok ? { ok: true } : { ok: false, reason: result.reason ?? "steer rejected" };
    },

    async stop(runId: string): Promise<boolean> {
      const run = state.getRun(runId);
      if (!run) return false;
      state.patchRun(runId, { status: "stopped" });
      return true;
    },
  };
}
