# Boundaries

This document describes the key boundary modules in the Tai architecture — the interfaces and contracts that separate subsystems and define how they communicate.

## Commander (`apps/tai/lib/tai/commander.ex`)

The Commander is the public API facade, implemented as a GenServer. It serves as the single entry point for external interaction with the Tai system.

- Delegates to sub-modules for venues, products, accounts, fees, markets, orders, advisors, and settings.
- Supports a `node:` option on all commands, enabling distributed querying across clustered Erlang nodes.
- All IEx helper commands (`Tai.IEx`) route through the Commander.

## Tai.Venues.Client (`apps/tai/lib/tai/venues/client.ex`)

The Client module is the boundary between the order management system and the venue adapters. It mediates all order operations:

- `create_order` — Submit a new order to a venue.
- `cancel_order` — Request cancellation of an existing order.
- `amend_order` — Modify an existing order (price, quantity).
- `amend_bulk_orders` — Batch-amend multiple orders in a single call.

Before submitting any order to a venue adapter, the Client checks the `send_orders` flag. When the flag is `false` (the default in development), orders are enqueued but never transmitted to the exchange, preventing accidental live trading.

## Tai.Venues.Adapter Behavior (`apps/tai/lib/tai/venues/adapter.ex`)

The Adapter behavior defines the contract that all venue implementations must satisfy. It is the formal boundary between Tai's core logic and exchange-specific code.

### Required Callbacks

| Callback | Description |
|---|---|
| `products/1` | Fetch available trading products from the venue. |
| `accounts/2` | Retrieve account balances. |
| `maker_taker_fees/2` | Fetch the fee structure (maker and taker rates). |
| `positions/2` | Get open positions (derivatives venues only). |
| `create_order/2` | Submit a new order. |
| `cancel_order/2` | Cancel an existing order. |
| `amend_order/2` | Modify an existing order. |
| `amend_bulk_orders/3` | Batch-modify multiple orders. |

Adapters that do not support a particular operation return `:not_implemented`.

## SystemBus (`apps/tai/lib/tai/system_bus.ex`)

The SystemBus provides registry-based publish/subscribe messaging within a Tai node.

- Built on top of `Registry` for lightweight, in-process pub/sub.
- Key topics include:
  - `:order_updated` — Broadcast whenever an order transitions state.
  - Advisor events — Lifecycle and strategy-specific events.
- Used by `TaiEvents` for broadcasting structured event records.
- Advisors and other consumers subscribe to topics to receive real-time notifications without direct coupling to the producing module.
