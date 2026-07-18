# Routing Comparison: Current vs Proposal (`quack`)

## Canonical Overlay Flowchart

```mermaid
flowchart TD
  A[S0_RECEIVE] --> B[S1_CLASSIFY]

  %% Proposal explicit quack path
  B -->|PROPOSAL: has_quack_invocation true| E[S4_QUACK_ROUTING]

  %% Shared simple path
  B -->|BOTH: is_simple_request true| D[S3_DIRECT_FLOW]

  %% Proposal recommendation path
  B -->|PROPOSAL: workflow_like and no quack| C[S2_RECOMMEND_QUACK]
  C -->|PROPOSAL: user reissues with quack| E
  C -->|PROPOSAL: user ignores recommendation| D

  %% Proposal default direct path
  B -->|PROPOSAL: else| D

  %% Current intent-based route path
  B -->|CURRENT: intent matched skill route| E

  %% Quack routing behavior
  E -->|PROPOSAL: ambiguous or invalid choice| E
  E -->|BOTH: mutating| F[S5_MUTATION_GATE]
  E -->|BOTH: non mutating| G[S6_EXECUTE]

  %% Direct behavior
  D -->|BOTH: mutating| F
  D -->|BOTH: non mutating| G

  %% Mutation gate
  F -->|BOTH: approval_received false| F
  F -->|BOTH: approval_received true| G

  %% Exit
  G --> H[S7_DONE]
```

## Legend

- **[CURRENT]**: Existing `rubber-duck` behavior (assistant intent-driven auto-routing).
- **[PROPOSAL]**: `routing-policy.md` behavior (`quack` explicit; soft recommendation otherwise).
- **[BOTH]**: Shared behavior/invariant in both modes.

## Invariants Preserved

1. No silent auto-routing outside explicit `quack` (proposal).
2. Soft recommendation is advisory; user can ignore.
3. Mutating actions must pass approval gate.
4. Never weaken trust-boundary validation, security controls, data-loss prevention, accessibility, or explicit user requirements.
