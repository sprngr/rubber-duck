export type DuckEngineRunStatus = "queued" | "running" | "completed" | "failed" | "stopped";
export type DuckEngineTerminalStatus = "completed" | "failed" | "stopped";

export type DuckRunStatusTimestamps = {
  queuedAt?: string;
  runningAt?: string;
  completedAt?: string;
  failedAt?: string;
  stoppedAt?: string;
};

export type DuckRunTelemetry = {
  turnCount: number;
  toolUses: number;
  tokenInput: number;
  tokenOutput: number;
  tokenCacheWrite: number;
  tokenTotal: number;
  contextPercent?: number;
  compactionCount: number;
  activeTools: string[];
  activityText?: string;
  timestamps: DuckRunStatusTimestamps;
};

export type DuckEngineRun = {
  runId: string;
  step: number;
  agent: string;
  status: DuckEngineRunStatus;
  telemetry?: DuckRunTelemetry;
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
  terminalStatus: DuckEngineTerminalStatus;
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
