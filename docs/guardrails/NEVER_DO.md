# NEVER DO

Critical constraints for the Tai trading toolkit. Violating any of these risks data corruption, financial loss, or system instability.

## 1. Never use floats for monetary values

All monetary and quantity values must use `Decimal`. Floating-point arithmetic introduces rounding errors that compound across trades and balance calculations.

```elixir
# WRONG
price = 0.1 + 0.2  # => 0.30000000000000004

# RIGHT
price = Decimal.add(~m[0.1], ~m[0.2])  # => #Decimal<0.3>
```

## 2. Never bypass the `send_orders` safety flag

The `send_orders` configuration flag prevents accidental order transmission to live exchanges. Never circumvent this check. When `false`, orders are enqueued but not sent to venues. This is the default in development for a reason.

## 3. Never modify order status outside the transition state machine

Order status changes must flow through the defined transition modules (`Tai.Orders.Transitions.*`). Each transition enforces valid state changes and records an audit trail. Directly updating the `:status` field on an order record breaks the state machine invariants and skips event broadcasting.

## 4. Never call venue adapter methods directly

Always go through `Tai.Venues.Client` to interact with exchanges. The client layer handles error normalization, timeout management, and adapter resolution. Calling adapter modules directly bypasses these safeguards.

```elixir
# WRONG
Tai.VenueAdapters.Binance.products(venue)

# RIGHT
Tai.Venues.Client.products(venue)
```

## 5. Never skip OrderTransitionWorker for order state changes

The `OrderTransitionWorker` ensures that state transitions for a given order are processed sequentially, preventing race conditions. Never apply transitions outside this worker, even if it seems simpler to update the order directly.

## 6. Never create orders without the EnqueueOrder service

All orders must be created through `Tai.Orders.Services.EnqueueOrder`. This service validates parameters, persists the order, and dispatches it to the worker pool. Creating order records manually skips validation and lifecycle management.

## 7. Never modify ETS stores directly

The runtime data stores (`ProductStore`, `FeeStore`, `AccountStore`, etc.) expose public APIs for reads and writes. Never call `:ets.insert/2`, `:ets.delete/2`, or similar functions against these tables directly. The store APIs maintain consistency and may broadcast change events.

## 8. Never publish on SystemBus reserved topics

The `Tai.SystemBus` uses specific topic conventions for order book updates, trade streams, and internal coordination. Publishing arbitrary messages on these reserved topics will interfere with advisors and other subscribers that depend on well-typed event payloads.

## 9. Never hardcode credentials or API keys

All exchange credentials must be managed through `confex` configuration, using `{:system, "ENV_VAR"}` or `{:system_file, "ENV_VAR"}` syntax. Never commit API keys, secrets, or passphrases to source code or configuration files.

## 10. Never use Logger directly

Use `TaiEvents` for all logging. TaiEvents provides structured, typed event logging that integrates with the system bus and supports downstream processing. Raw `Logger` calls bypass this infrastructure and produce unstructured output that is difficult to filter or analyze.

```elixir
# WRONG
require Logger
Logger.info("Order filled")

# RIGHT
TaiEvents.info(%Tai.Events.OrderFilled{...})
```
