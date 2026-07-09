export const DUCK_USAGE = {
  policy: "Usage: /duck policy on|off",
  mode: "Usage: /duck mode on|off",
  route: "Usage: /duck route <text>",
  routePreview: "Usage: /duck route preview <text>",
  followup: "Usage: /duck followup <text>",
  refine: "Usage: /duck refine [--replace] <text>",
  refineReplace: "Usage: /duck refine --replace <text>",
  reply: "Usage: /duck reply <requestId> <decision> [notes]",
} as const;

export const DUCK_HELP_LINES = [
  "Duck commands",
  "- /duck status|reset|on|off|policy on|off|mode on|off|route <text>",
  "- /duck proceed [summary] · /duck refine [--replace] <text> · /duck cancel",
  "- /duck route <text> · /duck route preview <text>",
  "- /duck pending · /duck runs · /duck reply <id> <continue|stop|retry-later> [notes]",
  "- /duck resume <runId> [step]",
  "- /duck followup <text> · /duck close-run",
  "- env: DUCK_AGENT_TIMEOUT_MS (default 120000), DUCK_AGENT_FORCE_KILL_GRACE_MS (default 2000)",
  "Direct ducklings: /duck-<agent>",
  "  /duck-reviewer /duck-investigator /duck-builder /duck-adversary /duck-dry /duck-simple",
] as const;
