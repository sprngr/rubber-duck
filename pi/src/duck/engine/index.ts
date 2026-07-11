import { createDuckEngineRuntime } from "./runtime.ts";
import { DuckEngineState } from "./state.ts";
import type { DuckEngine } from "./types.ts";

export type CreateDuckEngineDeps = {
  state?: DuckEngineState;
};

export function createDuckEngine(deps: CreateDuckEngineDeps = {}): DuckEngine {
  const runtime = createDuckEngineRuntime({ state: deps.state });

  return {
    async spawn(input) {
      return runtime.spawn(input);
    },
    listRuns() {
      return runtime.state.listRuns();
    },
    getRun(runId: string) {
      return runtime.state.getRun(runId);
    },
    async steer(runId: string, message: string) {
      return runtime.steer(runId, message);
    },
    async stop(runId: string) {
      return runtime.stop(runId);
    },
  };
}

export type {
  DuckEngine,
  DuckEngineRun,
  DuckEngineRunStatus,
  DuckEngineSpawnInput,
  DuckEngineSpawnResult,
  DuckEngineSteerResult,
} from "./types.ts";
