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

function normalizeInput(text: string): string {
  return text
    .toLowerCase()
    .replace(/[`'"(){}\[\],.:;!?]/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

function hasAny(text: string, terms: string[]): boolean {
  return terms.some((term) => text.includes(term));
}

function scoreTerms(text: string, terms: string[]): number {
  let score = 0;
  for (const term of terms) {
    if (text.includes(term)) score += 1;
  }
  return score;
}

const TRIAGE_TERMS = [
  "triage",
  "test coverage",
  "coverage",
  "coverage analysis",
  "what to test",
  "missing test",
  "untested",
  "test review",
  "bug severity",
  "pre pr planning",
  "pre-pr planning",
];

const DEBUG_TERMS = [
  "debug",
  "broken",
  "failing",
  "fails",
  "failure",
  "error",
  "exception",
  "stack trace",
  "bug",
  "wrong output",
  "root cause",
  "500",
  "investigate",
  "issue",
];

const REVIEW_TERMS = [
  "review",
  "code review",
  "pr review",
  "pull request",
  "diff",
  "audit",
  "changes",
  "snippet review",
];

const EXPLAIN_TERMS = [
  "explain",
  "what does this do",
  "walkthrough",
  "walk through",
  "explain function",
  "explain file",
  "explain snippet",
];

const TEACH_TERMS = [
  "teach me",
  "how does",
  "how do",
  "walk me through",
  "tutorial",
  "show me",
];

const DESIGN_TERMS = [
  "design",
  "tradeoff",
  "tradeoffs",
  "architecture",
  "evaluate approach",
  "help me choose",
  "risk model",
  "what could go wrong",
  "simplify",
];

const DUPLICATION_TERMS = ["duplicate", "duplication", "drift", "repeated logic", "copy paste", "shared rule"];
const TEST_GAP_TERMS = ["test gap", "coverage gap", "missing test", "untested", "what to test", "test coverage"];
const REPRO_WEAK_TERMS = [
  "hard to reproduce",
  "cant reproduce",
  "can t reproduce",
  "intermittent",
  "flaky",
  "unclear repro",
  "unknown repro",
];
const PATCH_SCOPE_TERMS = ["bounded patch", "small patch", "1-2 files", "one file", "two files"];
const PATCH_ACTION_TERMS = ["patch", "fix", "implement", "edit", "change code", "apply"];
const INLINE_PR_COMMENT_TERMS = ["inline pr comments", "inline review comments", "pr comments"];

export function routeAmbient(text: string): RouteDecision {
  const t = normalizeInput(text);

  const hasDuplicationSignal = hasAny(t, DUPLICATION_TERMS);
  const hasTestGapSignal = hasAny(t, TEST_GAP_TERMS);
  const hasReproWeakSignal = hasAny(t, REPRO_WEAK_TERMS);
  const hasBoundedPatchSignal = hasAny(t, PATCH_SCOPE_TERMS) && hasAny(t, PATCH_ACTION_TERMS);
  const hasIssueSignal = hasAny(t, DEBUG_TERMS);
  const hasReviewRequestSignal = hasAny(t, REVIEW_TERMS);
  const hasInlinePrCommentsSignal = hasAny(t, INLINE_PR_COMMENT_TERMS);

  const scores = {
    triage: scoreTerms(t, TRIAGE_TERMS),
    debug: scoreTerms(t, DEBUG_TERMS),
    review: scoreTerms(t, REVIEW_TERMS),
    explain: scoreTerms(t, EXPLAIN_TERMS),
    teach: scoreTerms(t, TEACH_TERMS),
    design: scoreTerms(t, DESIGN_TERMS),
  } as const;

  const maxScore = Math.max(
    scores.triage,
    scores.debug,
    scores.review,
    scores.explain,
    scores.teach,
    scores.design,
  );

  if (maxScore <= 0) return null;

  const priority: Array<keyof typeof scores> = ["triage", "debug", "review", "explain", "teach", "design"];
  const chosen = priority.find((key) => scores[key] === maxScore);
  if (!chosen) return null;

  if (chosen === "triage") {
    const executionChain: KnownDuckling[] = [hasInlinePrCommentsSignal ? "duck-reviewer" : "duck-investigator"];
    const metaChain: string[] = ["duck-triage(skill)", ...executionChain];

    return {
      intent: "triage",
      skill: "duck-triage",
      agent: executionChain[0],
      executionChain,
      metaChain,
      reason: "test/triage planning signal",
    };
  }

  if (chosen === "debug") {
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

  if (chosen === "review") {
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

  if (chosen === "explain") {
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

  if (chosen === "teach") {
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
