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
