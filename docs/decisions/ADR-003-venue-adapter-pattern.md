# ADR-003: Venue Adapter Pattern

- **Date:** 2026-03-11
- **Status:** Accepted

## Context

Tai must integrate with multiple cryptocurrency exchanges, each exposing different REST APIs, WebSocket protocols, product naming conventions, and order semantics. The system needs to:

- Present a uniform interface to the core trading logic regardless of the underlying exchange.
- Boot each venue reliably, fetching reference data (products, accounts, fees, positions) and establishing real-time streams before the venue is considered ready.
- Handle exchanges that do not support certain operations (e.g., positions on spot-only venues) without runtime crashes.
- Provide a clear template for contributors adding support for new exchanges.

## Decision

### Behaviour-based adapter contract

`Tai.Venues.Adapter` defines a behaviour with callbacks for all venue operations:

- `products/1` — fetch tradeable products.
- `accounts/2` — retrieve account balances.
- `maker_taker_fees/2` — query fee schedules.
- `positions/2` — fetch open positions (derivatives).
- `create_order/2`, `cancel_order/2`, `amend_order/2`, `amend_bulk_orders/3` — order lifecycle operations.

Each venue adapter module (e.g., `Tai.VenueAdapters.Binance`, `Tai.VenueAdapters.OkEx`) implements this behaviour. Operations that a particular venue does not support return `{:error, :not_implemented}`, allowing the core to handle graceful degradation without pattern-match failures.

### Two-phase venue start with concurrent initialization

When a venue is started, five async tasks run concurrently to minimize boot time:

1. Fetch products
2. Fetch accounts
3. Fetch positions
4. Fetch fees
5. Start the real-time stream supervisor

All five tasks are subject to a configurable timeout. If any required task fails, the venue does not transition to the `:running` state. This two-phase approach (start tasks, then await results) keeps venue boot fast while maintaining an all-or-nothing readiness guarantee.

### Client boundary layer

`Tai.Venues.Client` sits between the order management layer and the venue adapters. When the orders subsystem needs to create, cancel, or amend an order, it calls through `Tai.Venues.Client` rather than invoking the adapter directly. This boundary:

- Centralizes error handling and logging for venue calls.
- Provides a single seam for testing (the client can be mocked or stubbed).
- Decouples order state management from adapter implementation details.

### Stream supervisor and ConnectionAdapter macro

Each venue adapter that supports real-time data provides a stream supervisor (e.g., `Tai.VenueAdapters.Binance.StreamSupervisor`) that manages one or more WebSocket connections. WebSocket connections use the `Fresh` library and implement standardized callbacks via the `ConnectionAdapter` macro, which provides:

- Automatic reconnection with backoff.
- Heartbeat/ping management.
- Consistent message decoding and routing to the system bus.

This pattern ensures that all venue streams behave uniformly from the perspective of the rest of the system, while allowing each adapter to handle exchange-specific framing and subscription messages.

### Stub adapter as reference implementation

`Tai.VenueAdapters.Stub` is maintained as a minimal, fully-implemented adapter that serves two purposes:

- **Documentation by example.** New contributors can read the stub to understand the expected shape of each callback.
- **Testing scaffold.** Integration and unit tests use the stub adapter to exercise the venue lifecycle without requiring live exchange credentials.

## Consequences

### Positive

- **Uniform API.** Core trading logic (advisors, order management) is completely exchange-agnostic. Switching or adding venues is a configuration change plus an adapter module.
- **Fast boot.** Concurrent initialization means a venue with slow fee or position endpoints does not block product fetching or stream startup.
- **Safe degradation.** The `:not_implemented` convention lets spot-only adapters coexist with derivatives adapters without conditional logic in the core.
- **Clear contribution path.** The stub adapter and the behaviour definition together form a checklist for new adapter authors.

### Negative

- **Behaviour surface area.** The adapter behaviour has many callbacks. Venues with significantly different semantics (e.g., DEXs, on-chain settlement) may not map cleanly to the current callback set.
- **Timeout tuning.** The concurrent boot with a shared timeout means one slow endpoint can cause the entire venue start to fail. Per-task timeouts would add complexity but improve resilience.
- **Fresh library dependency.** All WebSocket handling is coupled to the Fresh library. Replacing it would require changes across every stream connection module.
- **Two-phase start opacity.** When a venue fails to start, diagnosing which of the five tasks timed out or errored requires inspecting logs rather than a structured error report.
