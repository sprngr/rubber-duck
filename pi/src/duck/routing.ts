import { KNOWN_DUCKLINGS } from "./agents.ts";

export type KnownDuckling = (typeof KNOWN_DUCKLINGS)[number];

export type RouteDecision = {
  intent: "review" | "debug" | "explain" | "teach" | "design" | "triage";
  skill: "duck-review" | "duck-debug" | "duck-explain" | "duck-teach" | "duck-design" | "duck-triage";
  agent: KnownDuckling;
  executionChain: KnownDuckling[];
  metaChain: string[];
  reason: string;
} | null;

export const UNRECOGNIZED_CLARIFY_QUESTION =
  "Quick clarify so I route correctly: should this be review, debug, explain, teach, design, or triage?";

function uniqueChain(chain: KnownDuckling[]): KnownDuckling[] {
  const out: KnownDuckling[] = [];
  for (const agent of chain) {
    if (!out.includes(agent)) out.push(agent);
  }
  return out;
}

export function routeAmbient(text: string): RouteDecision {
  const t = text.toLowerCase();

  const hasDuplicationSignal = /(duplicate|duplication|drift|repeated logic|copy\s?paste|shared-rule)/.test(t);
  const hasTestGapSignal = /(test gap|coverage gap|missing tests?|untested|what to test|test coverage)/.test(t);
  const hasReproWeakSignal = /(hard to reproduce|can'?t reproduce|intermittent|flaky|unclear repro|unknown repro)/.test(t);
  const hasBoundedPatchSignal =
    /(explicit bounded patch|bounded patch|small patch|1-2 files|one or two files|one file|two files)/.test(t) &&
    /(patch|fix|implement|edit|change code|apply)/.test(t);
  const hasIssueSignal = /(broken|failing|error|exception|bug|wrong output|500|issue)/.test(t);
  const hasReviewRequestSignal = /(review this|code review|review|pr review|audit|diff)/.test(t);
  const hasInlinePrCommentsSignal = /(inline pr comments|inline review comments|pr comments)/.test(t);

  // Priority: debug > review > explain > teach > design > triage
  if (/(debug this|debug|broken|failing|error|exception|stack trace|500|bug|root cause|complaint)/.test(t)) {
    const executionChain: KnownDuckling[] = ["duck-investigator"];
    const metaChain: string[] = ["duck-investigator"];

    if (hasReproWeakSignal) {
      metaChain.push("duck-triage(skill)");
    }
    if (hasBoundedPatchSignal) {
      executionChain.push("duck-builder");
      metaChain.push("duck-builder");
    }

    return {
      intent: "debug",
      skill: "duck-debug",
      agent: "duck-investigator",
      executionChain: uniqueChain(executionChain),
      metaChain,
      reason: "debug/failure signal",
    };
  }

  if (/(paste diff|review this|code review|\bdiff\b|pr review|audit)/.test(t) || hasReviewRequestSignal) {
    const executionChain: KnownDuckling[] = ["duck-reviewer", "duck-adversary", "duck-simple"];
    const metaChain: string[] = ["duck-reviewer", "duck-adversary", "duck-simple"];

    if (hasDuplicationSignal) {
      executionChain.push("duck-dry");
      metaChain.push("duck-dry");
    }
    if (hasTestGapSignal) {
      metaChain.push("duck-triage(skill)");
    }

    return {
      intent: "review",
      skill: "duck-review",
      agent: "duck-reviewer",
      executionChain: uniqueChain(executionChain),
      metaChain,
      reason: "review/diff signal",
    };
  }

  if (/(explain this|what does this do|explain this function|explain this file|explain this snippet)/.test(t)) {
    const executionChain: KnownDuckling[] = ["duck-investigator"];
    const metaChain: string[] = ["duck-investigator"];

    if (hasIssueSignal) {
      metaChain.push("duck-debug(skill)");
    }
    if (hasReviewRequestSignal) {
      executionChain.push("duck-reviewer");
      metaChain.push("duck-reviewer");
    }

    return {
      intent: "explain",
      skill: "duck-explain",
      agent: "duck-investigator",
      executionChain: uniqueChain(executionChain),
      metaChain,
      reason: "explain signal",
    };
  }

  if (/(teach me|how does .* work|walk me through)/.test(t)) {
    const executionChain: KnownDuckling[] = ["duck-simple"];
    const metaChain: string[] = ["duck-simple"];

    if (hasIssueSignal) {
      metaChain.push("duck-debug(skill)");
    }
    if (hasReviewRequestSignal) {
      executionChain.push("duck-reviewer");
      metaChain.push("duck-reviewer");
    }

    return {
      intent: "teach",
      skill: "duck-teach",
      agent: "duck-simple",
      executionChain: uniqueChain(executionChain),
      metaChain,
      reason: "teach/how-it-works signal",
    };
  }

  if (/(design this|tradeoff|tradeoffs|architecture|evaluate approach|help me choose|design)/.test(t)) {
    const executionChain: KnownDuckling[] = ["duck-simple", "duck-adversary"];
    const metaChain: string[] = ["duck-simple", "duck-adversary"];

    if (hasDuplicationSignal) {
      executionChain.push("duck-dry");
      metaChain.push("duck-dry");
    }
    if (hasIssueSignal) {
      metaChain.push("duck-debug(skill)");
    }

    return {
      intent: "design",
      skill: "duck-design",
      agent: "duck-simple",
      executionChain: uniqueChain(executionChain),
      metaChain,
      reason: "design/tradeoff signal",
    };
  }

  if (/(test coverage|what to test|pre-pr planning|pre pr planning|bug severity|triage)/.test(t)) {
    const executionChain: KnownDuckling[] = [hasInlinePrCommentsSignal ? "duck-reviewer" : "duck-investigator"];
    const metaChain: string[] = ["duck-triage(skill)"];
    if (hasInlinePrCommentsSignal) metaChain.push("duck-reviewer");

    return {
      intent: "triage",
      skill: "duck-triage",
      agent: executionChain[0],
      executionChain,
      metaChain,
      reason: "test/triage planning signal",
    };
  }

  return null;
}

export function fallbackRouteAfterClarification(_text: string): Exclude<RouteDecision, null> {
  return {
    intent: "debug",
    skill: "duck-debug",
    agent: "duck-investigator",
    executionChain: ["duck-investigator"],
    metaChain: ["duck-investigator"],
    reason: "post-clarification fallback",
  };
}
