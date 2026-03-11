# ADR-002: Order State Machine

- **Date:** 2026-03-11
- **Status:** Accepted

## Context

Tai needs to track orders through a complex lifecycle spanning multiple exchanges (venues), each with different confirmation semantics and failure modes. Orders move through many states — from initial enqueue, through venue acceptance, partial fills, amendments, cancellations, and various error conditions. The system must:

- Record the full audit trail of every state change for an order.
- Guarantee that concurrent events for the same order are applied in a consistent sequence.
- Support 14+ distinct order statuses and 19 transition types without a combinatorial explosion of ad-hoc update logic.
- Allow fire-and-forget submission of venue calls while still ensuring downstream state changes are safely serialized.

An earlier approach of directly mutating order records with conditional updates was fragile and made the audit trail implicit rather than explicit.

## Decision

### Polymorphic transitions in a single table

All order state changes are modelled as transition structs stored in the `order_transitions` table. `PolymorphicEmbed` is used so that each row can hold a different transition type (e.g., `AcceptCreate`, `Fill`, `Cancel`, `PassivePartialFill`, `VenueCreateError`) while sharing one schema and one table. Each transition struct implements the `Tai.Orders.Transition` behaviour, which defines three callbacks:

- `from/0` — the status(es) the order must currently be in for this transition to be valid.
- `attrs/1` — the changeset attributes to apply to the order record.
- `status/1` — the resulting status after the transition is applied.

### Optimistic locking on apply

`ApplyOrderTransition` reads the order's current status and compares it against the value returned by `from/0` before writing. If the status has already moved past the expected state (e.g., a late-arriving fill for an already-cancelled order), the transition is rejected. This optimistic-lock style check avoids database-level row locks while still preventing illegal state jumps.

### Hash-based sequential processing per order

`OrderTransitionWorker` routes transitions through a worker pool using a hash of the order's client ID. This guarantees that all transitions for a single order are processed sequentially, eliminating race conditions between concurrent venue callbacks for the same order, while still allowing transitions for different orders to be processed in parallel.

### Fire-and-forget venue calls

Venue interactions (create, cancel, amend) are dispatched via `Task.async` in a fire-and-forget pattern. The calling process enqueues the order and returns immediately. When the venue responds (or fails), the resulting transition is routed through the worker pool described above. This decouples the caller from venue latency and network errors.

### Order statuses

The full set of statuses covers the happy path, cancellation, amendment, and multiple error categories:

| Status | Description |
|---|---|
| `enqueued` | Order accepted locally, not yet sent to venue |
| `create_accepted` | Venue acknowledged the create request |
| `open` | Order is live on the venue order book |
| `partially_filled` | One or more fills received, quantity remaining |
| `filled` | Fully filled |
| `pending_cancel` | Cancel request sent, awaiting venue confirmation |
| `cancel_accepted` | Venue acknowledged the cancel request |
| `cancelled` | Order successfully cancelled |
| `pending_amend` | Amend request sent, awaiting venue confirmation |
| `amend_accepted` | Venue acknowledged the amend request |
| `create_error` | Local error before the order reached the venue |
| `venue_create_error` | Venue rejected the create request |
| `rescue_create_error` | Unexpected exception during create |
| Additional error states | Corresponding error variants for cancel/amend flows |

The 19 transition types in `apps/tai/lib/tai/orders/transitions/` encode every legal edge between these statuses.

## Consequences

### Positive

- **Full audit trail.** Every state change is a first-class record. Debugging, compliance, and analytics can query the transitions table directly.
- **Explicit state machine.** Legal transitions are encoded in behaviour implementations rather than scattered conditional logic. Adding a new transition is a single module plus a polymorphic embed registration.
- **Safe concurrency.** Hash-based routing serializes per-order work without a global lock, and the optimistic status check provides a second safety net.
- **Decoupled venue latency.** Callers are never blocked waiting on venue round-trips.

### Negative

- **Transition proliferation.** 19 transition modules is a large surface area. Each new venue-specific edge case may require a new module.
- **Optimistic lock retries.** Under heavy amendment or fill traffic for a single order, transitions may be rejected and need to be re-evaluated or logged as conflicts.
- **PolymorphicEmbed coupling.** The project depends on the `PolymorphicEmbed` library for serialization. Schema migrations require care when adding or renaming transition types.
- **In-memory routing.** The hash-based worker routing lives in the BEAM and is not persisted. If a node crashes mid-transition, in-flight transitions must be recovered from the database or event log.
