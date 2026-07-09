import { getMarkdownTheme, type ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Box, Container, Markdown, Spacer, Text } from "@earendil-works/pi-tui";
import { randomDuckWorkingAction } from "../../duck/working.ts";

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
          new Text(theme.fg("muted", `... ${bodyLines.length - collapsedLines} more lines (Ctrl+O to expand)`), 0, 0),
        );
      } else {
        container.addChild(new Text(theme.fg("muted", "Ctrl+O to expand"), 0, 0));
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
  pi.sendMessage({
    customType: "duck-subagent-run",
    content: `${icon} ${title}${body ? "\n\n" + body : ""}`,
    display: true,
    details: {
      title,
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

export function startInlineWorking(ctx: UiFeedbackContext, message: string): () => void {
  if (!ctx.ui.setWidget) return () => {};

  let frameIndex = 0;
  const render = () => {
    const frame = WORKING_SPINNER_FRAMES[frameIndex % WORKING_SPINNER_FRAMES.length] ?? "⠋";
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

export async function withWorking<T>(ctx: UiFeedbackContext, _message: string, fn: () => Promise<T>): Promise<T> {
  const indicatorText = randomDuckWorkingAction();
  ctx.ui.setWorkingVisible?.(true);
  ctx.ui.setWorkingMessage?.(indicatorText);
  const stopInline = startInlineWorking(ctx, indicatorText);
  try {
    return await fn();
  } finally {
    stopInline();
    ctx.ui.setWorkingMessage?.();
  }
}
