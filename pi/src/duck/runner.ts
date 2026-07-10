import { spawn } from "node:child_process";
import { mkdtemp, rm, writeFile } from "node:fs/promises";
import * as os from "node:os";
import * as path from "node:path";
import type { DuckAgentConfig } from "./agents.ts";

type MessageLike = { role?: string; content?: Array<{ type?: string; text?: string }> };

const DEFAULT_AGENT_TIMEOUT_MS = 120_000;
const FORCE_KILL_GRACE_MS = 2_000;

function positiveIntFromEnv(name: string, fallback: number): number {
  const raw = process.env[name];
  if (!raw) return fallback;
  const parsed = Number.parseInt(raw, 10);
  if (!Number.isFinite(parsed) || parsed <= 0) return fallback;
  return parsed;
}

function getFinalOutput(messages: MessageLike[]): string {
  for (let i = messages.length - 1; i >= 0; i--) {
    const msg = messages[i];
    if (msg?.role !== "assistant") continue;
    for (const part of msg.content ?? []) {
      if (part?.type === "text" && part.text) return part.text;
    }
  }
  return "";
}

export function truncateOutput(text: string, maxChars = 3000): string {
  if (text.length <= maxChars) return text;
  return `${text.slice(0, maxChars)}\n\n[truncated ${text.length - maxChars} chars]`;
}

function getPiInvocation(args: string[]): { command: string; args: string[] } {
  const currentScript = process.argv[1];
  const isBunVirtualScript = currentScript?.startsWith("/$bunfs/root/");
  if (currentScript && !isBunVirtualScript) {
    return { command: process.execPath, args: [currentScript, ...args] };
  }

  const execName = path.basename(process.execPath).toLowerCase();
  const isGenericRuntime = /^(node|bun)(\.exe)?$/.test(execName);
  if (!isGenericRuntime) return { command: process.execPath, args };

  return { command: "pi", args };
}

export async function runDuckAgent(
  agent: DuckAgentConfig,
  task: string,
  cwd: string,
  policyText?: string,
): Promise<{ output: string; exitCode: number; stderr: string }> {
  const timeoutMs = positiveIntFromEnv("DUCK_AGENT_TIMEOUT_MS", DEFAULT_AGENT_TIMEOUT_MS);
  const killGraceMs = positiveIntFromEnv("DUCK_AGENT_FORCE_KILL_GRACE_MS", FORCE_KILL_GRACE_MS);

  const args: string[] = ["--mode", "json", "-p", "--no-session", "--no-extensions"];
  if (agent.model) args.push("--model", agent.model);
  if (agent.tools?.length) args.push("--tools", agent.tools.join(","));

  let tmpDir: string | null = null;
  try {
    const parts: string[] = [];
    if (policyText?.trim()) {
      parts.push(`# Extension AGENTS.md policy\n\n${policyText.trim()}`);
    }
    if (agent.systemPrompt.trim()) {
      parts.push(`# Duck agent prompt (${agent.name})\n\n${agent.systemPrompt.trim()}`);
    }

    if (parts.length > 0) {
      tmpDir = await mkdtemp(path.join(os.tmpdir(), "pi-duck-agent-"));
      const promptPath = path.join(tmpDir, `${agent.name}.md`);
      await writeFile(promptPath, `${parts.join("\n\n---\n\n")}\n`, { encoding: "utf-8", mode: 0o600 });
      args.push("--append-system-prompt", promptPath);
    }

    args.push(task);

    const invocation = getPiInvocation(args);
    const messages: MessageLike[] = [];

    const { code, stderr } = await new Promise<{ code: number; stderr: string }>((resolve) => {
      const proc = spawn(invocation.command, invocation.args, {
        cwd,
        shell: false,
        stdio: ["ignore", "pipe", "pipe"],
      });

      let stderrBuf = "";
      let stdoutBuf = "";
      let settled = false;
      let timedOut = false;

      const finish = (result: { code: number; stderr: string }) => {
        if (settled) return;
        settled = true;
        resolve(result);
      };

      const timeoutId = setTimeout(() => {
        timedOut = true;
        stderrBuf = `${stderrBuf}${stderrBuf ? "\n" : ""}Timed out after ${timeoutMs}ms`;
        try {
          proc.kill("SIGTERM");
        } catch {
          // ignore kill failure
        }

        setTimeout(() => {
          if (settled) return;
          try {
            proc.kill("SIGKILL");
          } catch {
            // ignore kill failure
          }
          finish({ code: 124, stderr: stderrBuf.trim() });
        }, killGraceMs);
      }, timeoutMs);

      const processLine = (line: string) => {
        if (!line.trim()) return;
        try {
          const event = JSON.parse(line);
          if (event?.type === "message_end" && event?.message) {
            messages.push(event.message);
          }
        } catch {
          // ignore parse failures
        }
      };

      proc.stdout.on("data", (chunk) => {
        stdoutBuf += chunk.toString();
        const lines = stdoutBuf.split("\n");
        stdoutBuf = lines.pop() ?? "";
        for (const line of lines) processLine(line);
      });

      proc.stderr.on("data", (chunk) => {
        stderrBuf += chunk.toString();
      });

      proc.on("close", (exitCode) => {
        clearTimeout(timeoutId);
        if (stdoutBuf.trim()) processLine(stdoutBuf);
        if (timedOut) {
          finish({ code: 124, stderr: stderrBuf.trim() });
          return;
        }
        finish({ code: exitCode ?? 1, stderr: stderrBuf.trim() });
      });

      proc.on("error", (err) => {
        clearTimeout(timeoutId);
        finish({ code: 1, stderr: String(err) });
      });
    });

    return {
      output: getFinalOutput(messages),
      exitCode: code,
      stderr,
    };
  } finally {
    if (tmpDir) {
      try {
        await rm(tmpDir, { recursive: true, force: true });
      } catch {
        // ignore cleanup failure
      }
    }
  }
}
