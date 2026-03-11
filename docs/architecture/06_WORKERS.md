# Workers

This document describes the worker architecture that powers order processing in Tai.

## Orders.Supervisor

The `Orders.Supervisor` manages two distinct subsystems for order processing:

### 1. Worker Pool (Poolboy)

A poolboy-managed pool of worker processes handles order operations.

- **Default pool size:** 5 workers.
- **Max overflow:** 2 additional workers under load.
- Workers handle `create`, `cancel`, and `amend` operations.
- Each operation is dispatched via `Task.async` for fire-and-forget submission to the venue through `Tai.Venues.Client`.
- The pool absorbs bursts of order activity without overwhelming venue connections.

### 2. OrderTransitionWorker

A set of workers responsible for applying order state transitions.

- **Default count:** 2 workers.
- **Routing:** Hash-based routing using `rem(hash(client_id), worker_count)`.
- This ensures that all state transitions for the same order are routed to the same worker, serializing updates and preventing race conditions.
- Different orders may be processed concurrently across different workers.

## Order Creation Flow (`Worker.create/2`)

The order creation flow proceeds through these steps:

1. **Check `send_orders` flag** — If the flag is `false`, the order is enqueued but not submitted to the exchange.
2. **Enqueue order in database** — The order is persisted with an initial `enqueued` state via Ecto.
3. **Async Task** — A `Task.async` call submits the order to the venue through `Tai.Venues.Client`.
4. **Venue response** — On receiving the venue's response (acknowledgment, rejection, or error), the result is dispatched to the appropriate `OrderTransitionWorker`.

## OrderTransitionWorker

Each `OrderTransitionWorker` is a GenServer that receives `{transition, order}` tuples.

- Calls `ApplyOrderTransition`, which executes an `Ecto.Multi` transaction to:
  - Validate the state transition is legal (e.g., `enqueued` to `open`, not `filled` to `enqueued`).
  - Update the order record in the database.
  - Broadcast the state change via the SystemBus (`:order_updated` topic).
- The transactional approach ensures that order state is always consistent, even under concurrent updates.
- Hash-based routing guarantees that transitions for a single order are never processed in parallel, eliminating ordering bugs.
