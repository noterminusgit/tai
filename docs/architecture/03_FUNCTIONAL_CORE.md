# Functional Core: Order State Machine

## Overview

The order lifecycle is modeled as an explicit state machine with 20 named transitions. Each transition is a struct implementing three callbacks:

- `from/0` — Returns the list of valid source statuses
- `attrs/1` — Extracts attributes to apply to the order from the transition payload
- `status/1` — Returns the target status after the transition

Transitions are applied atomically via `Tai.Orders.Services.ApplyOrderTransition`, which uses an `Ecto.Multi` to:

1. Load the order and verify its current status matches one of the transition's `from/0` values (optimistic status check)
2. Insert an `OrderTransition` record with the transition struct as a `PolymorphicEmbed`
3. Update the `Order` record with new attributes and status
4. Fire the registered order callback (if any)

If the optimistic status check fails, the transition is written to `FailedOrderTransition` instead, and an `OrderUpdateInvalidStatus` event is published.

## Transition Map

### Creation Phase

| Transition | From | To | Description |
|---|---|---|---|
| `AcceptCreate` | `enqueued` | `create_accepted` | Venue acknowledged order submission |
| `VenueCreateError` | `enqueued` | `create_error` | Venue returned an error on create |
| `RescueCreateError` | `enqueued` | `create_error` | Exception rescued during create |

### Active Phase

| Transition | From | To | Description |
|---|---|---|---|
| `Open` | `enqueued`, `create_accepted` | `open` | Order is live on the venue |
| `PartialFill` | 7 states* | `partially_filled` | Partial execution received |
| `Fill` | 7 states* | `filled` | Order fully filled |

*PartialFill and Fill accept from: `enqueued`, `create_accepted`, `open`, `pending_cancel`, `cancel_accepted`, `pending_amend`, `amend_accepted`

### Cancel Phase

| Transition | From | To | Description |
|---|---|---|---|
| `PendCancel` | `open` | `pending_cancel` | Cancel request submitted |
| `AcceptCancel` | `pending_cancel` | `cancel_accepted` | Venue acknowledged cancel |
| `Cancel` | `pending_cancel`, `cancel_accepted` | `canceled` | Order successfully canceled |
| `VenueCancelError` | `pending_cancel` | `cancel_error` | Venue returned error on cancel |
| `RescueCancelError` | `pending_cancel` | `cancel_error` | Exception rescued during cancel |

### Amend Phase

| Transition | From | To | Description |
|---|---|---|---|
| `PendAmend` | `open` | `pending_amend` | Amend request submitted |
| `AcceptAmend` | `pending_amend` | `amend_accepted` | Venue acknowledged amend |
| `Amend` | `pending_amend`, `amend_accepted` | `open` | Order amended, returns to open |
| `VenueAmendError` | `pending_amend` | `amend_error` | Venue returned error on amend |
| `RescueAmendError` | `pending_amend` | `amend_error` | Exception rescued during amend |

### Terminal Phase

| Transition | From | To | Description |
|---|---|---|---|
| `Expire` | `open` | `expired` | Order expired (e.g., TIF elapsed) |
| `Reject` | `open` | `rejected` | Order rejected by venue |
| `Skip` | `enqueued` | `skipped` | Order skipped (send_orders disabled) |

### Passthrough

| Transition | From | To | Description |
|---|---|---|---|
| `Passthrough` | `:*` (any) | `passthrough_*` | Pass-through for venue-initiated state changes that bypass normal flow |

Passthrough target statuses: `passthrough_create_accepted`, `passthrough_open`, `passthrough_partially_filled`, `passthrough_filled`, `passthrough_expired`

## State Diagram

```
                                ┌──────────────┐
                                │   enqueued   │
                                └──────┬───────┘
                       ┌───────────────┼───────────────┐
                       ▼               ▼               ▼
              ┌────────────────┐ ┌────────────┐ ┌────────────┐
              │ create_accepted│ │create_error│ │  skipped   │
              └───────┬────────┘ └────────────┘ └────────────┘
                      │
          ┌───────────┼───────────────────────────────┐
          ▼           ▼                               ▼
    ┌───────────┐  ┌──────┐                    ┌────────────┐
    │partial_fill│  │filled│                    │    open    │
    └───────────┘  └──────┘                    └─────┬──────┘
                                      ┌──────────────┼──────────────┐
                                      ▼              ▼              ▼
                               ┌──────────────┐┌──────────────┐┌─────────┐
                               │pending_cancel││pending_amend ││expired/ │
                               └──────┬───────┘└──────┬───────┘│rejected │
                                      │               │        └─────────┘
                                 ┌────┼────┐     ┌────┼────┐
                                 ▼    ▼    ▼     ▼    ▼    ▼
                          ┌────────┐┌──┐┌────┐┌────────┐┌──┐┌────┐
                          │canceled││CE││ CA ││  open  ││AE││ AA │
                          └────────┘└──┘└──┬─┘└────────┘└──┘└──┬─┘
                                           │                    │
                                           ▼                    ▼
                                      ┌────────┐          ┌────────┐
                                      │canceled│          │  open  │
                                      └────────┘          └────────┘

CE = cancel_error, CA = cancel_accepted
AE = amend_error, AA = amend_accepted
```

Note: `PartialFill` and `Fill` transitions can occur from any of the 7 active states (arrows omitted for clarity). The `Passthrough` transition can originate from any state.

## Callback Mechanism

When an order is created, a callback function can be registered in the `OrderCallbackStore` (ETS). After a transition is successfully applied, `ApplyOrderTransition` looks up and invokes the callback with the updated order. This allows callers (typically advisors) to receive synchronous notification of order state changes without polling.
