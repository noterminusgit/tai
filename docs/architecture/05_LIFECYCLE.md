# Lifecycle

This document traces the key lifecycle sequences in Tai, from application boot through venue startup, WebSocket connections, and advisor operation.

## Boot Sequence

1. `Application.start` — The OTP application starts, building the supervision tree.
2. Supervision tree initialization — Core supervisors and registries are started.
3. `start_phase(:venues)` — A dedicated start phase triggers venue loading.
4. `Tai.Venues.Config.parse()` — Parses venue configuration from the application environment.
5. VenueStore registration — Parsed venue configs are registered in the VenueStore for runtime lookup.
6. `Tai.Venues.Supervisor.start/1` — Starts the supervisor for each configured venue.
7. Boot GenServer — Each venue runs a Boot process that orchestrates its initialization.
8. `Tai.Fleets.Services.Load` — Fleet configurations are loaded and advisor instances are prepared.
9. Advisor startup — Individual advisor GenServers are started according to fleet/factory configuration.
10. `after_boot` callback — Advisors receive the `after_start/1` callback, signaling readiness.

## Venue Start (`Tai.Venues.Start`)

When a venue starts, it launches five concurrent `Task.async` tasks, subject to a configurable timeout:

1. **Products** — Fetch available trading products from the exchange.
2. **Accounts** — Retrieve account balances.
3. **Positions** — Fetch open positions (derivatives venues).
4. **Fees** — Load maker/taker fee schedules.
5. **Stream** — Start the real-time WebSocket stream.

Products must complete first because the other tasks depend on product data. Once products are available, accounts, positions, fees, and the stream proceed concurrently. The stream is started using a Fresh WebSocket connection.

## WebSocket Lifecycle

WebSocket connections use the Fresh library and follow its behavior contract:

- `handle_connect` — Called when the WebSocket connection is established. Used to send initial subscription messages and start heartbeat timers.
- `handle_in` — Called for each incoming WebSocket frame. The adapter parses the message and updates order books, trade streams, or other state.
- `handle_disconnect` — Called when the connection drops. Triggers cleanup and auto-reconnection logic.

A heartbeat timer sends periodic ping/pong frames to keep the connection alive and detect stale connections.

On disconnect, the connection module automatically attempts to reconnect, preserving subscriptions and resuming data flow.

## Advisor Lifecycle

1. `start_link` — The advisor GenServer is started under its fleet supervisor.
2. `init` — Traps exits (`Process.flag(:trap_exit, true)`) to ensure clean shutdown.
3. `continue(:subscribe)` — Subscribes to the configured market quote and trade topics via PubSub.
4. `continue(:after_start)` — Invokes the `after_start/1` callback, allowing the advisor to perform initialization logic (e.g., placing initial orders, loading state).
5. Callback loop — The advisor enters its main loop, receiving and processing:
   - `handle_market_quote/2` — Order book updates.
   - `handle_trade/2` — Trade events.
6. `on_terminate` — On shutdown (supervisor stop, node shutdown), the `on_terminate/2` callback is invoked for cleanup (e.g., cancelling open orders, persisting state).
