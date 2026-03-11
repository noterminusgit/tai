# Observability

[Getting Started](./GETTING_STARTED.md) | [Built with Tai](./BUILT_WITH_TAI.md) | [Commands](./COMMANDS.md) | [Architecture](./ARCHITECTURE.md) | [Examples](../apps/examples/README.md) | [Configuration](./CONFIGURATION.md)

Tai provides two observability mechanisms: **Telemetry** for metrics and **TaiEvents** for structured event logging.

## Telemetry Metrics

Using the [telemetry](https://elixirschool.com/blog/instrumenting-phoenix-with-telemetry-part-one/)
library, `tai` emits metrics that can be used to visualize and alert on the
inner workings of your trading systems.

```elixir
# Stream connection metrics (emitted by Tai.Venues.Telemetry)
[:tai, :venues, :stream, :connect]     # measurements: %{total: count}, metadata: %{venue: atom}
[:tai, :venues, :stream, :disconnect]  # measurements: %{total: count}, metadata: %{venue: atom}
[:tai, :venues, :stream, :terminate]   # measurements: %{total: count}, metadata: %{venue: atom}
```

`Tai.Venues.Telemetry` is a GenServer that subscribes to `{:venues, :stream}` SystemBus topic, counts events per venue in ETS, and emits telemetry with cumulative totals.

## TaiEvents (Structured Event Logging)

All internal events are emitted through the `TaiEvents` library, which provides:
- Pub/sub broadcasting via `TaiEvents.firehose_subscribe()`
- Structured logging via `TaiEvents.LogEvent` protocol implementations
- Event encoding via `TaiEvents.Event.encode!/1`

Events are logged by `Tai.EventsLogger` which subscribes to TaiEvents and routes to Elixir's Logger at appropriate levels.

### Event Catalog

#### Boot Lifecycle

| Event | Level | Trigger | Key Fields |
|-------|-------|---------|------------|
| `BootAdvisors` | info | All venues started, fleets loaded | `loaded_fleets`, `loaded_advisors`, `started_advisors` |
| `BootAdvisorsError` | error | Venue startup failure during boot | `reason` |

#### Venue Events

| Event | Level | Trigger | Key Fields |
|-------|-------|---------|------------|
| `VenueStart` | info | Venue started successfully | `venue` |
| `VenueStartError` | error | Venue failed to start | `venue`, `reason` |
| `VenueStop` | info | Venue stopped | `venue` |

#### Stream Events

| Event | Level | Trigger | Key Fields |
|-------|-------|---------|------------|
| `StreamConnect` | info | WebSocket connected | `venue` |
| `StreamDisconnect` | warning | WebSocket disconnected | `venue`, `reason` |
| `StreamTerminate` | warning | WebSocket terminated | `venue`, `reason` |
| `StreamError` | warning | Stream processing error | `venue`, `error` |
| `StreamAuthOk` | info | Stream authentication succeeded | `venue` |
| `StreamSubscribeOk` | info | Channel subscription succeeded | `venue` |
| `StreamChannelInvalid` | warning | Invalid channel subscription | `venue`, `channel` |
| `StreamMessageUnhandled` | warning | Unrecognized stream message | `venue`, `msg` |
| `StreamMessageOrderUpdateUnhandled` | warning | Unparseable order update | `venue`, `msg` |
| `StreamMessageInvalidOrderClientId` | warning | Unknown order client ID | `venue`, `client_id` |

#### Order Events

| Event | Level | Trigger | Key Fields |
|-------|-------|---------|------------|
| `OrderUpdated` | info | Order state changed | `client_id`, `status`, `venue_id`, `price`, `qty`, `cumulative_qty`, `leaves_qty` |
| `OrderUpdateInvalidStatus` | warning | Invalid state transition attempted | `client_id`, `was`, `required`, `action` |
| `OrderUpdateNotFound` | warning | Update for unknown order | `client_id`, `action` |

#### Advisor Events

| Event | Level | Trigger | Key Fields |
|-------|-------|---------|------------|
| `AdvisorHandleMarketQuoteError` | warning | Exception in `handle_market_quote/2` | `advisor_id`, `fleet_id`, `error`, `stacktrace` |
| `AdvisorHandleMarketQuoteInvalidReturn` | warning | Non-`{:ok, store}` return | `advisor_id`, `fleet_id`, `return_value` |
| `AdvisorHandleTradeError` | warning | Exception in `handle_trade/2` | `advisor_id`, `fleet_id`, `error`, `stacktrace` |
| `AdvisorHandleTradeInvalidReturn` | warning | Non-`{:ok, store}` return | `advisor_id`, `fleet_id`, `return_value` |

#### Hydration Events (Initial Data Loading)

| Event | Level | Trigger | Key Fields |
|-------|-------|---------|------------|
| `HydrateProducts` | info | Products fetched from venue | `venue_id`, `total`, `filtered` |
| `HydrateAccounts` | info | Accounts fetched from venue | `venue_id`, `total` |
| `HydratePositions` | info | Positions fetched from venue | `venue_id`, `total` |

#### Derivative Events

| Event | Level | Trigger | Key Fields |
|-------|-------|---------|------------|
| `Settlement` | info | Contract settlement | `venue_id`, `symbol`, `price`, `timestamp` |
| `Funding` | info | Funding rate update | `venue_id`, `symbol`, `rate` |
| `PositionUpdate` | info | Position changed | `venue_id`, `symbol`, `data` |
| `InsertLiquidation` | info | Liquidation order created | `venue_id`, `symbol` |
| `UpdateLiquidationPrice` | info | Liquidation price changed | `venue_id`, `symbol` |
| `UpdateLiquidationLeavesQty` | info | Liquidation qty changed | `venue_id`, `symbol` |
| `DeleteLiquidation` | info | Liquidation completed | `venue_id`, `symbol` |

#### Monitoring Events

| Event | Level | Trigger | Key Fields |
|-------|-------|---------|------------|
| `ConnectedStats` | info | Connection statistics | Adapter-specific |
| `BitmexStreamConnectionLimitDetails` | info | BitMEX connection limits | `remaining`, `limit` |
| `Trade` | info | Trade executed | `venue_id`, `symbol`, `price`, `qty`, `side` |

### Subscribing to Events

```elixir
# Subscribe to all events
TaiEvents.firehose_subscribe()

# Events arrive as messages:
# {TaiEvents.Event, %Tai.Events.SomeEvent{}, :info | :warning | :error}
```
