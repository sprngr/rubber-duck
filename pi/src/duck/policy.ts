import { readFile } from "node:fs/promises";
import * as path from "node:path";
import { fileURLToPath } from "node:url";

export function bundledPolicyPath(): string {
  const here = path.dirname(fileURLToPath(import.meta.url));
  return path.resolve(here, "../../AGENTS.md");
}

export async function loadBundledPolicyText(): Promise<string> {
  return readFile(bundledPolicyPath(), "utf-8");
}

export async function bundledPolicyExists(): Promise<boolean> {
  try {
    await readFile(bundledPolicyPath(), "utf-8");
    return true;
  } catch {
    return false;
  }
}
