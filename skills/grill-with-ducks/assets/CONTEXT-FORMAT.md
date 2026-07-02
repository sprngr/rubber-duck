# CONTEXT.md Format

## Structure

```md
# {Context Name}

{One or two sentence description of what this context is and why it exists.}

## Language

**Order**:
{A one or two sentence description of the term}
_Avoid_: Purchase, transaction

**Invoice**:
A request for payment sent to a customer after delivery.
_Avoid_: Bill, payment request

**Customer**:
A person or organization that places orders.
_Avoid_: Client, buyer, account
```

## Rules

- **Be opinionated.** When multiple words exist for the same concept, pick the canonical term and list aliases to avoid.
- **Flag conflicts explicitly.** If a term is ambiguous, add it to "Flagged ambiguities" with the chosen resolution.
- **Keep definitions tight.** One or two sentences max. Define what it IS, not implementation details.
- **Show relationships.** Use bold term names and cardinality where obvious.
- **Only include domain terms.** General programming concepts do not belong unless they are domain-defining.
- **Group terms by subheading** when natural clusters emerge.
- **Add one example dialogue.** Show a brief dev/domain-expert conversation that demonstrates term boundaries.

## Single vs multi-context repos

**Single context (most repos):** One `CONTEXT.md` at repo root.

**Multiple contexts:** A `CONTEXT-MAP.md` at repo root lists contexts, locations, and relationships:

```md
# Context Map

## Contexts

- [Ordering](./src/ordering/CONTEXT.md) — receives and tracks customer orders
- [Billing](./src/billing/CONTEXT.md) — generates invoices and processes payments
- [Fulfillment](./src/fulfillment/CONTEXT.md) — manages warehouse picking and shipping

## Relationships

- **Ordering → Fulfillment**: Ordering emits `OrderPlaced` events; Fulfillment consumes them to start picking
- **Fulfillment → Billing**: Fulfillment emits `ShipmentDispatched` events; Billing consumes them to generate invoices
- **Ordering ↔ Billing**: Shared types for `CustomerId` and `Money`
```

The skill infers which structure applies:

- If `CONTEXT-MAP.md` exists, read it first to find relevant context
- If only root `CONTEXT.md` exists, treat repo as single context
- If neither exists, propose creating root `CONTEXT.md` once first term is resolved

When multiple contexts exist and topic mapping is unclear, ask.
