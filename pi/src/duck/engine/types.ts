export type DuckEngineRunStatus = "queued" | "running" | "completed" | "failed" | "stopped";

export type DuckEngineRun = {
  runId: string;
  step: number;
  agent: string;
  status: DuckEngineRunStatus;
  output?: string;
  error?: string;
  activeAgentId?: string;
};

export type DuckEngineSpawnInput = {
  runId: string;
  step: number;
  agent: string;
  prompt: string;
  cwd: string;
  policyText?: string;
};

export type DuckEngineSpawnResult = {
  ok: boolean;
  output: string;
  exitCode: number;
  stderr: string;
  agentId?: string;
};

export type DuckEngineSteerResult = {
  ok: boolean;
  reason?: string;
};

export interface DuckEngine {
  spawn(input: DuckEngineSpawnInput): Promise<DuckEngineSpawnResult>;
  getRun(runId: string): DuckEngineRun | undefined;
  listRuns(): DuckEngineRun[];
  steer(runId: string, message: string): Promise<DuckEngineSteerResult>;
  stop(runId: string): Promise<boolean>;
}
