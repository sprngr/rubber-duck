# Design Patterns and Decision Prompts

Common architectural symptoms and corresponding decision prompts.

## Pattern Catalog

### State Management

| Symptom | Prompt |
|---------|--------|
| Deep nested conditionals | "Are these hiding a state machine or just needing guard clauses?" |
| Unstructured control flow | "Is a state machine justified, or does this just need early returns?" |
| Shared mutable state | "Does this need immutability, or is a message pass enough?" |

### Coupling and Boundaries

| Symptom | Prompt |
|---------|--------|
| Tight coupling between modules | "Is an interface worth the abstraction cost here?" |
| Circular dependencies | "Dependency inversion or facade — which indirection fits?" |
| God object / manager class | "What behavior can be pushed into domain objects?" |

### API and Contracts

| Symptom | Prompt |
|---------|--------|
| Breaking API changes | "Versioned endpoints or feature flags — which surface area do you accept?" |
| Frequent schema changes | "Is this schema too normalized, or is denormalization premature?" |
| Client-server coupling | "Is a shared contract library worth the deployment coordination cost?" |

### Performance

| Symptom | Prompt |
|---------|--------|
| N+1 query pattern | "Is batching/caching justified, or premature optimization?" |
| Large payload sizes | "Is pagination/streaming worth the client complexity?" |
| Blocking operations | "Is async worth the error-handling complexity here?" |

### Testability

| Symptom | Prompt |
|---------|--------|
| Hard-to-mock dependencies | "Is dependency injection justified, or can you use a simpler seam?" |
| Flaky tests | "Is this testing implementation or contract?" |
| Slow test suite | "Is parallelization possible, or is this a test pyramid problem?" |

## Usage

1. Identify symptom from developer's description
2. Offer corresponding prompt as question
3. Let developer choose between alternatives presented in prompt
4. If prompt doesn't match symptom, skip pattern catalog and use Alternative Suggestion Pattern

## Anti-Patterns to Avoid

Never suggest:
- Microservices for monolith pain (suggest bounded contexts first)
- New database for query complexity (suggest read models / caching first)
- Event sourcing for audit log needs (suggest append-only table first)
- CQRS for read/write split (suggest indexed views first)

Always compare lightweight option to heavyweight option. Let developer choose tradeoff.
