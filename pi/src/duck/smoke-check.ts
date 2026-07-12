import { buildClarificationInput, isQuackInput, shouldSkipAmbientInput } from "./input-flow.ts";
import { workflowKickoffPrefix } from "./workflow-session.ts";
import { createInitialTelemetry, simulateQueuePump } from "./engine/session-runner.ts";
import type { DuckEngineSpawnResult } from "./engine/types.ts";

function assert(condition: boolean, message: string): void {
  if (!condition) throw new Error(message);
}

function runSmoke(): void {
  // route / quack recognition
  assert(isQuackInput("quack"), "expected quack to be recognized");
  assert(isQuackInput("  QuAcK  "), "expected quack recognition to be case/trim tolerant");
  assert(!isQuackInput("duck"), "expected non-quack input to be rejected");

  // ambient input skip gates
  assert(shouldSkipAmbientInput({ enabled: false, ambientMode: true, source: "user", text: "hello" }), "expected disabled duck to skip");
  assert(shouldSkipAmbientInput({ enabled: true, ambientMode: false, source: "user", text: "hello" }), "expected ambient off to skip");
  assert(shouldSkipAmbientInput({ enabled: true, ambientMode: true, source: "extension", text: "hello" }), "expected extension source to skip");
  assert(shouldSkipAmbientInput({ enabled: true, ambientMode: true, source: "user", text: " /duck status" }), "expected slash command to skip");
  assert(!shouldSkipAmbientInput({ enabled: true, ambientMode: true, source: "user", text: "hello" }), "expected normal user text to pass");

  // clarification payload shaping
  const clarified = buildClarificationInput("Do review", "focus on commands");
  assert(
    clarified === "Do review\n\nClarification: focus on commands",
    "expected clarification payload shape to remain stable",
  );

  // workflow kickoff contract
  const kickoff = workflowKickoffPrefix("duck-review", "Do review");
  assert(kickoff === "/duck-review Do review; continue chat & wait for `/duck proceed`.", "expected kickoff prefix contract");

  // queue transition contract (queued -> running within capacity)
  const queueSeed: Array<"queued" | "running"> = ["running", "queued", "queued"];
  const pumped = simulateQueuePump(queueSeed, 2);
  assert(pumped[0] === "running", "expected existing running slot to remain running");
  assert(pumped[1] === "running", "expected first queued job to start when capacity exists");
  assert(pumped[2] === "queued", "expected remaining queued job to stay queued when capacity is full");

  // terminal status contract should remain explicit and stable
  const terminalResult: DuckEngineSpawnResult = {
    ok: false,
    output: "",
    exitCode: 1,
    stderr: "stopped by user",
    terminalStatus: "stopped",
  };
  assert(terminalResult.terminalStatus === "stopped", "expected explicit stopped terminal status");

  // telemetry contract: unknown numeric fields are NaN until authoritatively sampled
  const telem = createInitialTelemetry();
  assert(Number.isNaN(telem.turnCount), "expected turnCount to be unknown (NaN) before sampling");
  assert(Number.isNaN(telem.toolUses), "expected toolUses to be unknown (NaN) before sampling");
  assert(Array.isArray(telem.activeTools), "expected activeTools to remain array-shaped");
  assert(Boolean(telem.timestamps.queuedAt), "expected queuedAt timestamp to be seeded");

  console.log("duck smoke: ok");
}

try {
  runSmoke();
} catch (error) {
  const message = error instanceof Error ? error.message : String(error);
  console.error(`duck smoke: failed — ${message}`);
  process.exitCode = 1;
}
