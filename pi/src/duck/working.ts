export const DUCK_WORKING_ACTIONS = [
  "Waddling through clues",
  "Polishing the beak",
  "Flapping through context",
  "Quacking at edge cases",
  "Diving for root cause",
  "Herding ducklings",
  "Preening the plan",
  "Tracing little footprints",
  "Sniffing out regressions",
  "Pecking at flaky paths",
  "Untangling call chains",
  "Sorting logs by splash radius",
  "Checking assumptions twice",
  "Hunting sneaky nils",
  "Spotting brittle seams",
  "Weighing tradeoffs",
  "Sharpening the hypothesis",
  "Mapping the execution trail",
  "Following the breadcrumb crumbs",
  "Stress-testing the plan",
  "Reviewing risky diffs",
  "Triaging rough edges",
  "Lining up rollback options",
  "Cross-checking invariants",
  "Pressure-testing edge conditions",
  "Folding noise into signal",
  "Aligning with duck policy",
  "Keeping scope tight",
  "Preparing a safe patch",
  "Double-checking user intent",
  "Inspecting tool output",
  "Smoothing the UX ripples",
] as const;

export function randomDuckWorkingAction(): string {
  const index = Math.floor(Math.random() * DUCK_WORKING_ACTIONS.length);
  return `${DUCK_WORKING_ACTIONS[index] ?? "Waddling"}...`;
}
