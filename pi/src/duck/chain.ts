import { truncateOutput } from "./runner.ts";
import type { DuckInvokeContext, DuckInvokeResult } from "./orchestrator.ts";

export type DuckChainTask = {
  agent: string;
  task?: string;
};

export type DuckChainStep =
  | {
      mode: "single";
      task: DuckChainTask;
    }
  | {
      mode: "parallel";
      tasks: DuckChainTask[];
      options: {
        concurrency: number;
        failFast: boolean;
      };
    };

export type DuckChainPlan = {
  steps: DuckChainStep[];
};

export type DuckChainItemResult = {
  step: number;
  mode: "single" | "parallel";
  agent: string;
  task: string;
  ok: boolean;
  output: string;
  exitCode: number;
  stderr: string;
};

export type DuckChainExecutionResult = {
  items: DuckChainItemResult[];
  succeeded: number;
  failed: number;
  lastOutput: string;
};

function splitTopLevel(input: string, separator: "->" | "|"): string[] {
  const out: string[] = [];
  let current = "";
  let quote: '"' | "'" | null = null;
  let parenDepth = 0;
  let bracketDepth = 0;

  for (let i = 0; i < input.length; i++) {
    const ch = input[i];
    const next = input[i + 1];

    if (quote) {
      current += ch;
      if (ch === quote && input[i - 1] !== "\\") quote = null;
      continue;
    }

    if (ch === '"' || ch === "'") {
      quote = ch;
      current += ch;
      continue;
    }

    if (ch === "(") parenDepth += 1;
    if (ch === ")") parenDepth = Math.max(0, parenDepth - 1);
    if (ch === "[") bracketDepth += 1;
    if (ch === "]") bracketDepth = Math.max(0, bracketDepth - 1);

    const atTop = parenDepth === 0 && bracketDepth === 0;

    if (separator === "->" && atTop && ch === "-" && next === ">") {
      out.push(current.trim());
      current = "";
      i += 1;
      continue;
    }

    if (separator === "|" && atTop && ch === "|") {
      out.push(current.trim());
      current = "";
      continue;
    }

    current += ch;
  }

  if (current.trim()) out.push(current.trim());
  return out;
}

function stripMatchingQuotes(value: string): string {
  const trimmed = value.trim();
  if (trimmed.length < 2) return trimmed;
  const first = trimmed[0];
  const last = trimmed[trimmed.length - 1];
  if ((first === '"' || first === "'") && first === last) {
    return trimmed.slice(1, -1);
  }
  return trimmed;
}

function parseTaskSegment(segment: string): DuckChainTask | null {
  const trimmed = segment.trim();
  if (!trimmed) return null;

  const match = trimmed.match(/^([^\s()[\]|]+)(.*)$/);
  if (!match) return null;

  const agent = match[1].trim();
  let rest = (match[2] ?? "").trim();
  if (!agent) return null;

  if (!rest) return { agent };
  if (rest.startsWith("--")) return { agent, task: rest.slice(2).trim() };
  return { agent, task: stripMatchingQuotes(rest) };
}

function parseParallelOptions(raw: string): { concurrency: number; failFast: boolean } {
  const defaults = { concurrency: 4, failFast: false };
  const trimmed = raw.trim();
  if (!trimmed) return defaults;

  const match = trimmed.match(/^\[(.*)\]$/);
  if (!match) return defaults;

  const options = { ...defaults };
  for (const token of match[1].split(",").map((t) => t.trim()).filter(Boolean)) {
    if (token === "failFast") {
      options.failFast = true;
      continue;
    }

    const keyValue = token.split("=");
    if (keyValue.length !== 2) continue;
    const key = keyValue[0].trim();
    const value = keyValue[1].trim();

    if (key === "concurrency") {
      const parsed = Number.parseInt(value, 10);
      if (Number.isFinite(parsed) && parsed > 0) options.concurrency = parsed;
    }
  }

  return options;
}

function parseStep(rawStep: string): DuckChainStep | null {
  const step = rawStep.trim();
  if (!step) return null;

  if (!step.startsWith("(")) {
    const task = parseTaskSegment(step);
    return task ? { mode: "single", task } : null;
  }

  let quote: '"' | "'" | null = null;
  let depth = 0;
  let closeIndex = -1;
  for (let i = 0; i < step.length; i++) {
    const ch = step[i];
    if (quote) {
      if (ch === quote && step[i - 1] !== "\\") quote = null;
      continue;
    }
    if (ch === '"' || ch === "'") {
      quote = ch;
      continue;
    }
    if (ch === "(") depth += 1;
    if (ch === ")") {
      depth -= 1;
      if (depth === 0) {
        closeIndex = i;
        break;
      }
    }
  }

  if (closeIndex < 0) return null;

  const inside = step.slice(1, closeIndex).trim();
  const optionsRaw = step.slice(closeIndex + 1).trim();
  const parts = splitTopLevel(inside, "|");
  if (parts.length < 2) return null;

  const tasks = parts.map(parseTaskSegment).filter((t): t is DuckChainTask => Boolean(t));
  if (tasks.length < 2) return null;

  return {
    mode: "parallel",
    tasks,
    options: parseParallelOptions(optionsRaw),
  };
}

export function splitChainAndInput(raw: string): { chainSpec: string; inputTask: string } {
  const input = raw.trim();
  if (!input) return { chainSpec: "", inputTask: "" };

  let quote: '"' | "'" | null = null;
  let parenDepth = 0;
  let bracketDepth = 0;

  for (let i = 0; i < input.length - 1; i++) {
    const ch = input[i];
    const next = input[i + 1];

    if (quote) {
      if (ch === quote && input[i - 1] !== "\\") quote = null;
      continue;
    }

    if (ch === '"' || ch === "'") {
      quote = ch;
      continue;
    }

    if (ch === "(") parenDepth += 1;
    if (ch === ")") parenDepth = Math.max(0, parenDepth - 1);
    if (ch === "[") bracketDepth += 1;
    if (ch === "]") bracketDepth = Math.max(0, bracketDepth - 1);

    const atTop = parenDepth === 0 && bracketDepth === 0;
    if (!atTop) continue;

    if (ch === "-" && next === "-" && input[i - 1] === " " && input[i + 2] === " ") {
      return {
        chainSpec: input.slice(0, i - 1).trim(),
        inputTask: input.slice(i + 3).trim(),
      };
    }
  }

  return { chainSpec: input, inputTask: "" };
}

export function parseDuckChainSpec(raw: string): { plan: DuckChainPlan | null; error?: string } {
  const chainSpec = raw.trim();
  if (!chainSpec) return { plan: null, error: "Missing chain definition." };

  const rawSteps = splitTopLevel(chainSpec, "->");
  if (rawSteps.length === 0) return { plan: null, error: "Missing chain steps." };

  const steps: DuckChainStep[] = [];
  for (const rawStep of rawSteps) {
    const parsed = parseStep(rawStep);
    if (!parsed) return { plan: null, error: `Invalid chain step: ${rawStep}` };
    steps.push(parsed);
  }

  return { plan: { steps } };
}

function resolveTask(taskTemplate: string | undefined, inputTask: string, previousOutput: string): string {
  if (taskTemplate && taskTemplate.trim()) {
    return taskTemplate
      .replace(/\{input\}/g, inputTask)
      .replace(/\{previous\}/g, previousOutput)
      .trim();
  }

  if (previousOutput.trim()) return previousOutput.trim();
  return inputTask.trim();
}

async function mapWithConcurrencyLimit<TIn, TOut>(
  items: TIn[],
  concurrency: number,
  failFast: boolean,
  fn: (item: TIn, index: number) => Promise<TOut>,
): Promise<TOut[]> {
  if (items.length === 0) return [];

  const limit = Math.max(1, Math.min(concurrency, items.length));
  const results: TOut[] = new Array(items.length);
  let nextIndex = 0;
  let shouldStop = false;

  const workers = new Array(limit).fill(null).map(async () => {
    while (true) {
      if (failFast && shouldStop) return;
      const current = nextIndex++;
      if (current >= items.length) return;

      const result = await fn(items[current], current);
      results[current] = result;

      if (failFast) {
        const maybeFailed = result as unknown as { ok?: boolean };
        if (maybeFailed?.ok === false) shouldStop = true;
      }
    }
  });

  await Promise.all(workers);
  return results.filter((r) => r !== undefined);
}

export async function executeDuckChain(params: {
  plan: DuckChainPlan;
  inputTask: string;
  invokeAgent(agentName: string, task: string, ctx: DuckInvokeContext): Promise<DuckInvokeResult>;
  ctx: DuckInvokeContext;
  continueOnError?: boolean;
}): Promise<DuckChainExecutionResult> {
  const continueOnError = params.continueOnError ?? true;
  const items: DuckChainItemResult[] = [];
  let previousOutput = "";

  for (let i = 0; i < params.plan.steps.length; i++) {
    const stepIndex = i + 1;
    const step = params.plan.steps[i];

    if (step.mode === "single") {
      const task = resolveTask(step.task.task, params.inputTask, previousOutput);
      const result = await params.invokeAgent(step.task.agent, task, params.ctx);
      items.push({
        step: stepIndex,
        mode: "single",
        agent: step.task.agent,
        task,
        ok: result.ok,
        output: result.output,
        exitCode: result.exitCode,
        stderr: result.stderr,
      });

      if (result.ok && result.output.trim()) {
        previousOutput = truncateOutput(result.output, 1500);
      }

      if (!result.ok && !continueOnError) break;
      continue;
    }

    const groupResults = await mapWithConcurrencyLimit(
      step.tasks,
      step.options.concurrency,
      step.options.failFast,
      async (taskDef) => {
        const task = resolveTask(taskDef.task, params.inputTask, previousOutput);
        const result = await params.invokeAgent(taskDef.agent, task, params.ctx);
        return {
          step: stepIndex,
          mode: "parallel" as const,
          agent: taskDef.agent,
          task,
          ok: result.ok,
          output: result.output,
          exitCode: result.exitCode,
          stderr: result.stderr,
        };
      },
    );

    items.push(...groupResults);

    const successfulOutputs = groupResults
      .filter((r) => r.ok && r.output.trim())
      .map((r) => `### ${r.agent}\n${truncateOutput(r.output, 700)}`);

    if (successfulOutputs.length > 0) {
      previousOutput = truncateOutput(successfulOutputs.join("\n\n"), 1500);
    }

    if (!continueOnError && groupResults.some((r) => !r.ok)) break;
  }

  const failed = items.filter((item) => !item.ok).length;
  const succeeded = items.length - failed;
  return {
    items,
    failed,
    succeeded,
    lastOutput: previousOutput,
  };
}

export function formatDuckChainSummary(result: DuckChainExecutionResult): string {
  const lines: string[] = [];
  lines.push(`Chain complete: ${result.succeeded} succeeded, ${result.failed} failed.`);

  for (const item of result.items) {
    if (item.ok) {
      lines.push(`✅ step ${item.step} ${item.agent}`);
      continue;
    }

    const reason = item.stderr || `exit ${item.exitCode}`;
    lines.push(`❌ step ${item.step} ${item.agent} — ${reason}`);
  }

  return lines.join("\n");
}
