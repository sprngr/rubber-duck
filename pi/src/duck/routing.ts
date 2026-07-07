import { KNOWN_DUCKLINGS } from "./agents.ts";

export type RouteDecision = {
  agent: (typeof KNOWN_DUCKLINGS)[number];
  reason: string;
} | null;

export function routeAmbient(text: string): RouteDecision {
  const t = text.toLowerCase();

  // Priority order:
  // debug > review > design > simplify > dry > builder
  if (/(debug|broken|failing|failure|error|exception|stack trace|500|bug|investigate|root cause)/.test(t)) {
    return { agent: "duck-investigator", reason: "debug/failure signal" };
  }
  if (/(^|\s)(review|code review|diff|pr review|audit)(\s|$)/.test(t)) {
    return { agent: "duck-reviewer", reason: "review/diff signal" };
  }
  if (/(design|tradeoff|architecture|threat|rollback|edge case|what could go wrong|risk model)/.test(t)) {
    return { agent: "duck-adversary", reason: "design/risk signal" };
  }
  if (/(simplify|simplification|reduce complexity|refactor|clean up)/.test(t)) {
    return { agent: "duck-simple", reason: "complexity/simplification signal" };
  }
  if (/(duplicate|duplication|drift|dry|repeated logic|copy paste)/.test(t)) {
    return { agent: "duck-dry", reason: "duplication/drift signal" };
  }
  if (/(implement|patch|change code|fix this|make it pass|apply fix|edit files)/.test(t)) {
    return { agent: "duck-builder", reason: "implementation signal" };
  }

  return null;
}
