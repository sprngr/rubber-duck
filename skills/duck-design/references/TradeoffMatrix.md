# Tradeoff Matrix Guide

Comparison framework for multi-option design decisions.

## Standard Dimensions

| Dimension | What to Evaluate |
|-----------|------------------|
| Complexity (build) | Lines of code, new dependencies, learning curve |
| Complexity (maintain) | Debugging ease, upgrade path, documentation needs |
| Performance | Latency, throughput, resource usage |
| Reliability | Failure modes, recovery paths, edge case handling |
| Flexibility | Extension points, future changes cost |
| Time to ship | Implementation hours, testing surface, rollout risk |

## How to Fill

Each cell: "high" / "med" / "low" or brief rationale (≤10 words).

Example:

| Dimension | Option A: REST | Option B: GraphQL | Option C: gRPC |
|-----------|----------------|-------------------|----------------|
| Complexity (build) | Low (stdlib only) | Med (schema + resolvers) | High (protobuf + codegen) |
| Complexity (maintain) | Low | Med (breaking schema changes) | Low (typed contracts) |
| Performance | Med (overfetch) | Med (N+1 risk) | High (binary, HTTP/2) |
| Reliability | High (mature) | Med (query complexity attacks) | High (backpressure built-in) |
| Flexibility | Low (fixed endpoints) | High (client queries) | Low (fixed protos) |
| Time to ship | 2 days | 5 days | 7 days |

## Usage Pattern

1. Generate matrix with relevant dimensions
2. Fill each cell for each option
3. Ask developer: "Which dimension is non-negotiable?"
4. Identify option that wins on that dimension
5. Show tradeoffs that option introduces
6. Confirm acceptance

## When to Skip

- Only one viable option (no real choice)
- Choice is reversible (implement faster option first, measure, pivot if needed)
- Developer already decided (use Alternative Suggestion Pattern instead to validate)
