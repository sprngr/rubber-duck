import { buildClarificationInput, isQuackInput, shouldSkipAmbientInput } from "./input-flow.ts";
import { workflowKickoffPrefix } from "./workflow-session.ts";

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
  const kickoff = workflowKickoffPrefix("duck-review");
  assert(kickoff === "load duck-review, continue chat & wait for `/duck proceed`.", "expected kickoff prefix contract");

  console.log("duck smoke: ok");
}

try {
  runSmoke();
} catch (error) {
  const message = error instanceof Error ? error.message : String(error);
  console.error(`duck smoke: failed — ${message}`);
  process.exitCode = 1;
}
