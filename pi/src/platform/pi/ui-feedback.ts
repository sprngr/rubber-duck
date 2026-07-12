import { getMarkdownTheme, type ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Box, Container, Markdown, Spacer, Text } from "@earendil-works/pi-tui";
import { randomDuckWorkingAction } from "../../duck/working.ts";
import type { DuckRunTelemetry } from "../../duck/engine/types.ts";

export type WorkingIndicatorOptions = {
  frames: string[];
  intervalMs?: number;
};

export type UiFeedbackContext = {
  ui: {
    notify(message: string, level?: "info" | "warning" | "error"): void;
    setWorkingMessage?(message?: string): void;
    setWorkingVisible?(visible: boolean): void;
    setWorkingIndicator?(options?: WorkingIndicatorOptions): void;
    setWidget?(key: string, content: string[] | undefined): void;
    theme: {
      fg(color: string, text: string): string;
    };
  };
};

export type DuckWorkingState = {
  frame?: string;
  text?: string;
};

export type DuckWorkingOptions = {
  onFrame?: (state: DuckWorkingState) => void;
  shouldShowInline?: () => boolean;
  onStop?: () => void;
};

export type DuckWidgetRun = {
  runId: string;
  state: "queued" | "running" | "needs_attention" | "completed" | "failed" | "stopped";
  nextStep: number;
  totalSteps: number;
  startedAt: string;
  needsReply?: boolean;
  turnCount?: number;
  toolUses?: number;
  tokenTotal?: number;
  contextPercent?: number;
  compactionCount?: number;
  activeTools?: string[];
  activityText?: string;
};

export type RunBlockOptions = {
  forceExpanded?: boolean;
  nonExpandable?: boolean;
  helperText?: string[];
  notifyHelper?: boolean;
};

const WORKING_SPINNER_FRAMES = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"];

export function stripFencedBackticks(text: string): string {
  return text
    .split("\n")
    .filter((line) => {
      const t = line.trim();
      return t !== "```" && t !== "```text";
    })
    .join("\n");
}

export function registerDuckMessageRenderers(pi: ExtensionAPI): void {
  pi.registerMessageRenderer("duck-user-input", (message, _options, theme) => {
    const content = typeof message.content === "string" ? message.content : "";
    return new Text(`${theme.fg("accent", "❯")} ${content}`, 0, 0);
  });

  pi.registerMessageRenderer("duck-subagent-run", (message, options, theme) => {
    const content = typeof message.content === "string" ? message.content : "";
    const lines = content.split("\n");
    const title = lines[0] ?? "🦆 Subagent";
    const body = stripFencedBackticks(lines.slice(1).join("\n").trim());

    const details =
      (message.details as {
        level?: "info" | "warning" | "error";
        forceExpanded?: boolean;
        nonExpandable?: boolean;
      } | undefined) ?? {};
    const level = details.level ?? "info";
    const forceExpanded = details.forceExpanded === true;
    const nonExpandable = details.nonExpandable === true;
    const titleColor = level === "error" ? "error" : level === "warning" ? "warning" : "toolTitle";

    const collapsedLines = 3;
    const bodyLines = body ? body.split("\n") : [];
    const isCollapsedView = nonExpandable ? false : !(options.expanded || forceExpanded);
    const showCollapsed = isCollapsedView && bodyLines.length > collapsedLines;
    const visibleBody = isCollapsedView ? bodyLines.slice(0, collapsedLines).join("\n") : body;

    const box = new Box(1, 1, (text) => theme.bg("customMessageBg", text));
    const container = new Container();
    container.addChild(new Text(theme.fg(titleColor, theme.bold(title)), 0, 0));

    if (visibleBody) {
      container.addChild(new Spacer(1));
      if (!isCollapsedView) {
        container.addChild(new Markdown(visibleBody, 0, 0, getMarkdownTheme()));
      } else {
        container.addChild(new Text(theme.fg("toolOutput", visibleBody), 0, 0));
      }
    }

    if (isCollapsedView && !nonExpandable) {
      container.addChild(new Spacer(1));
      if (showCollapsed) {
        container.addChild(
          new Text(theme.fg("muted", `+${bodyLines.length - collapsedLines} more lines · Ctrl+O`), 0, 0),
        );
      } else {
        container.addChild(new Text(theme.fg("muted", "Ctrl+O for details"), 0, 0));
      }
    }

    box.addChild(container);
    return box;
  });
}

export function extractMessageText(message: unknown): string {
  if (!message || typeof message !== "object") return "";
  const content = (message as { content?: unknown }).content;
  if (typeof content === "string") return content.trim();

  if (Array.isArray(content)) {
    return content
      .map((part) => {
        if (!part || typeof part !== "object") return "";
        const p = part as { type?: unknown; text?: unknown };
        if (p.type === "text" && typeof p.text === "string") return p.text;
        return "";
      })
      .filter(Boolean)
      .join("\n")
      .trim();
  }

  return "";
}

export function sendRunBlock(
  pi: ExtensionAPI,
  title: string,
  body: string,
  level: "info" | "warning" | "error" = "info",
  options?: RunBlockOptions,
  ctx?: UiFeedbackContext,
): void {
  const icon = level === "error" ? "🦆❌" : level === "warning" ? "🦆⚠️" : "🦆";
  const visualTitle = title.startsWith("Duck ·") ? title : `Duck · ${title}`;
  pi.sendMessage({
    customType: "duck-subagent-run",
    content: `${icon} ${visualTitle}${body ? "\n\n" + body : ""}`,
    display: true,
    details: {
      title: visualTitle,
      level,
      forceExpanded: options?.forceExpanded === true,
      nonExpandable: options?.nonExpandable === true,
    },
  });

  if (options?.notifyHelper && options.helperText && ctx) {
    ctx.ui.notify(options.helperText.join(" · "), level === "error" ? "error" : level === "warning" ? "warning" : "info");
  }
}

export function sendUserInline(pi: ExtensionAPI, text: string): void {
  pi.sendMessage({
    customType: "duck-user-input",
    content: text,
    display: true,
  });
}

export function applyWorkingStyle(ctx: UiFeedbackContext): void {
  ctx.ui.setWorkingVisible?.(true);
  ctx.ui.setWorkingIndicator?.({
    frames: WORKING_SPINNER_FRAMES.map((frame) => ctx.ui.theme.fg("accent", frame)),
    intervalMs: 80,
  });
}

function formatElapsed(startedAt: string): string {
  const started = Date.parse(startedAt);
  if (!Number.isFinite(started)) return "-";
  const sec = Math.max(0, Math.floor((Date.now() - started) / 1000));
  if (sec < 60) return `${sec}s`;
  const min = Math.floor(sec / 60);
  const rem = sec % 60;
  return `${min}m${rem.toString().padStart(2, "0")}s`;
}

function formatCompactTokens(total?: number): string | undefined {
  if (typeof total !== "number" || !Number.isFinite(total) || total <= 0) return undefined;
  if (total >= 1_000_000) return `${(total / 1_000_000).toFixed(1)}M tok`;
  if (total >= 1_000) return `${(total / 1_000).toFixed(1)}k tok`;
  return `${total} tok`;
}

function hasAuthoritativeNumber(value: number | undefined): value is number {
  return typeof value === "number" && Number.isFinite(value);
}

function normalizeLabel(value: string): string {
  return value.trim().toLowerCase().replace(/\s+/g, " ");
}

function shortStateLabel(state: DuckWidgetRun["state"]): string {
  switch (state) {
    case "running":
      return "run";
    case "queued":
      return "wait";
    case "needs_attention":
      return "need";
    case "completed":
      return "done";
    case "failed":
      return "fail";
    case "stopped":
      return "stop";
    default:
      return state;
  }
}

export type DuckCompletionCardInput = {
  runId: string;
  title: string;
  status: "completed" | "failed" | "stopped";
  telemetry?: DuckRunTelemetry;
  durationMs?: number;
  outputPreview?: string;
  error?: string;
  transcriptPath?: string;
};

export function buildDuckCompletionCard(input: DuckCompletionCardInput): {
  title: string;
  body: string;
  level: "info" | "warning" | "error";
} {
  const level = input.status === "completed" ? "info" : input.status === "stopped" ? "warning" : "error";
  const statusLabel = input.status === "completed" ? "completed" : input.status === "stopped" ? "stopped" : "failed";

  const stats: string[] = [];
  if (hasAuthoritativeNumber(input.telemetry?.turnCount) && input.telemetry.turnCount > 0) {
    stats.push(`⟳${input.telemetry.turnCount}`);
  }
  if (hasAuthoritativeNumber(input.telemetry?.toolUses) && input.telemetry.toolUses > 0) {
    stats.push(`${input.telemetry.toolUses} tools`);
  }
  const tokens = formatCompactTokens(input.telemetry?.tokenTotal);
  if (tokens) stats.push(tokens);
  if (typeof input.telemetry?.contextPercent === "number" && Number.isFinite(input.telemetry.contextPercent)) {
    stats.push(`${Math.round(input.telemetry.contextPercent)}% ctx`);
  }
  if (hasAuthoritativeNumber(input.telemetry?.compactionCount) && input.telemetry.compactionCount > 0) {
    stats.push(`↻${input.telemetry.compactionCount}`);
  }
  if (typeof input.durationMs === "number" && Number.isFinite(input.durationMs) && input.durationMs > 0) {
    const sec = Math.max(0, Math.floor(input.durationMs / 1000));
    stats.push(sec < 60 ? `${sec}s` : `${Math.floor(sec / 60)}m${(sec % 60).toString().padStart(2, "0")}s`);
  }

  const summary = stats.length > 0 ? stats.join(" · ") : "(no telemetry yet)";
  const preview = input.outputPreview?.trim() || (input.error ? `Error: ${input.error}` : "No output.");
  const transcript = input.transcriptPath?.trim() ? `\ntranscript: ${input.transcriptPath.trim()}` : undefined;

  return {
    title: `Run ${statusLabel} · ${input.runId}`,
    level,
    body: [`${input.title}`, summary, `⎿ ${preview}`, transcript].filter(Boolean).join("\n")
  };
}

export function updateDuckRunsWidget(ctx: UiFeedbackContext, runs: DuckWidgetRun[], working?: DuckWorkingState): void {
  if (!ctx.ui.setWidget) return;
  if (runs.length === 0) {
    ctx.ui.setWidget("duck-runs", undefined);
    return;
  }

  const runningCount = runs.filter((run) => run.state === "running").length;
  const queuedCount = runs.filter((run) => run.state === "queued").length;
  const attentionCount = runs.filter((run) => run.state === "needs_attention" || run.needsReply).length;
  const recentCount = runs.filter((run) => run.state === "completed" || run.state === "failed" || run.state === "stopped").length;

  const countSegments = [
    runningCount > 0 ? `${runningCount} running` : undefined,
    queuedCount > 0 ? `${queuedCount} queued` : undefined,
    attentionCount > 0 ? `${attentionCount} needs attention` : undefined,
    recentCount > 0 ? `${recentCount} recent` : undefined,
  ].filter((part): part is string => Boolean(part));
  const countSummary = countSegments.length > 0 ? countSegments.join(" · ") : "idle";

  const header = working?.text?.trim()
    ? `🦆 ${ctx.ui.theme.fg("warning", working.frame ?? "⠋")} ${ctx.ui.theme.fg("dim", working.text.trim())} · ${countSummary}`
    : `🦆 Active runs · ${countSummary}`;

  const formatRunLine = (run: DuckWidgetRun, includeIcon = true): string => {
    const stateIcon = run.state === "queued"
      ? "◌"
      : run.state === "running"
        ? "⠹"
        : run.state === "needs_attention"
          ? "⏸"
          : run.state === "completed"
            ? "✓"
            : run.state === "stopped"
              ? "■"
              : "✗";
    const attention = run.needsReply ? "reply" : undefined;
    const stats: string[] = [];
    if (hasAuthoritativeNumber(run.turnCount) && run.turnCount > 0) stats.push(`⟳${run.turnCount}`);
    if (hasAuthoritativeNumber(run.toolUses) && run.toolUses > 0) stats.push(`${run.toolUses} tools`);
    const tokens = formatCompactTokens(run.tokenTotal);
    if (tokens) stats.push(tokens);
    if (typeof run.contextPercent === "number" && Number.isFinite(run.contextPercent)) {
      stats.push(`${Math.round(run.contextPercent)}% ctx`);
    }
    if (hasAuthoritativeNumber(run.compactionCount) && run.compactionCount > 0) stats.push(`↻${run.compactionCount}`);
    if (Array.isArray(run.activeTools) && run.activeTools.length > 0) {
      stats.push(run.activeTools.length > 1 ? `${run.activeTools.length} active tools` : `tool:${run.activeTools[0]}`);
    }
    const statsSegment = stats.length > 0 ? ` · ${stats.join(" · ")}` : "";
    const phase = run.state === "queued"
      ? "queued"
      : run.state === "completed" || run.state === "failed" || run.state === "stopped"
        ? "recent"
        : formatElapsed(run.startedAt);
    const stepSegment = run.nextStep === 1 && run.totalSteps === 1 ? undefined : `p:${run.nextStep}/${run.totalSteps}`;
    const activity = run.activityText?.trim();
    const activitySegment = activity && normalizeLabel(activity) !== normalizeLabel(run.state)
      ? `a:${activity}`
      : undefined;
    const segments = [
      run.runId,
      `s:${shortStateLabel(run.state)}`,
      attention,
      stepSegment,
      `t:${phase}`,
      activitySegment,
      statsSegment ? statsSegment.slice(3) : undefined,
    ].filter((part): part is string => Boolean(part));
    const prefix = includeIcon ? `${stateIcon} ` : "";
    return `${prefix}${segments.join(" · ")}`;
  };

  if (working?.text?.trim() && runs.length > 0) {
    const collapsed = formatRunLine(runs[0], false);
    const remaining = runs.slice(1).map((run) => formatRunLine(run, true));
    ctx.ui.setWidget("duck-runs", [`${header} · ${collapsed}`, ...remaining]);
    return;
  }

  const lines = [header, ...runs.map((run) => formatRunLine(run, true))];

  ctx.ui.setWidget("duck-runs", lines);
}

export function startInlineWorking(
  ctx: UiFeedbackContext,
  message: string,
  options?: DuckWorkingOptions,
): () => void {
  if (!ctx.ui.setWidget) return () => {};

  let frameIndex = 0;
  const render = () => {
    const frame = WORKING_SPINNER_FRAMES[frameIndex % WORKING_SPINNER_FRAMES.length] ?? "⠋";
    options?.onFrame?.({ frame, text: message });
    if (options?.shouldShowInline && !options.shouldShowInline()) {
      ctx.ui.setWidget?.("duck-working-inline", undefined);
      frameIndex += 1;
      return;
    }
    ctx.ui.setWidget?.("duck-working-inline", [`${ctx.ui.theme.fg("warning", frame)} ${ctx.ui.theme.fg("dim", message)}`]);
    frameIndex += 1;
  };

  render();
  const timer = setInterval(render, 80);

  return () => {
    clearInterval(timer);
    ctx.ui.setWidget?.("duck-working-inline", undefined);
  };
}

export async function withWorking<T>(
  ctx: UiFeedbackContext,
  _message: string,
  fn: () => Promise<T>,
  options?: DuckWorkingOptions,
): Promise<T> {
  const indicatorText = randomDuckWorkingAction();
  ctx.ui.setWorkingVisible?.(true);
  ctx.ui.setWorkingMessage?.(indicatorText);
  const stopInline = startInlineWorking(ctx, indicatorText, options);
  try {
    return await fn();
  } finally {
    stopInline();
    options?.onStop?.();
    ctx.ui.setWorkingMessage?.();
  }
}
