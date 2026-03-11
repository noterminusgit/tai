# Domain Model

## Core Structs

### Tai.Venue

Top-level venue configuration. One struct per configured exchange.

| Field | Type | Description |
|---|---|---|
| `id` | atom | Unique venue identifier (e.g., `:binance`) |
| `adapter` | module | Venue adapter module implementing `Tai.Venues.Adapter` |
| `channels` | list | WebSocket channels to subscribe to |
| `products` | string | Product filter pattern |
| `market_streams` | list | Market stream subscriptions |
| `credentials` | map | API key/secret pairs keyed by credential id |
| `quote_depth` | integer | Depth of order book quotes to maintain |
| `timeout` | integer | HTTP request timeout in milliseconds |
| `start_on_boot` | boolean | Whether to auto-start during boot phase |
| `opts` | map | Adapter-specific options |

### Tai.Venues.Product

Represents a tradeable instrument on a venue.

| Field | Type | Description |
|---|---|---|
| `venue_id` | atom | Parent venue identifier |
| `symbol` | atom | Normalized product symbol |
| `venue_symbol` | string | Exchange-native symbol |
| `base` | atom | Base asset |
| `quote` | atom | Quote asset |
| `status` | atom | Trading status (e.g., `:trading`) |
| `type` | atom | Product type (`:spot`, `:future`, `:swap`) |
| `price_increment` | Decimal | Minimum price tick |
| `size_increment` | Decimal | Minimum size tick |
| `min_price` | Decimal | Minimum allowed price |
| `max_price` | Decimal | Maximum allowed price |
| `min_size` | Decimal | Minimum order size |
| `max_size` | Decimal | Maximum order size |
| `value` | Decimal | Contract value (derivatives) |
| `is_quanto` | boolean | Quanto contract flag |
| `is_inverse` | boolean | Inverse contract flag |
| `maker_fee` | Decimal | Maker fee rate |
| `taker_fee` | Decimal | Taker fee rate |

### Tai.Orders.Order (Ecto Schema)

Persistent order record tracking full lifecycle.

| Field | Type | Description |
|---|---|---|
| `client_id` | UUID | Primary key, client-generated |
| `venue` | atom | Target venue |
| `credential` | atom | Credential used for submission |
| `venue_order_id` | string | Exchange-assigned order ID |
| `product_symbol` | atom | Instrument being traded |
| `side` | atom | `:buy` or `:sell` |
| `type` | atom | `:limit`, `:market`, etc. |
| `time_in_force` | atom | `:gtc`, `:ioc`, `:fok` |
| `price` | Decimal | Limit price |
| `qty` | Decimal | Original order quantity |
| `cumulative_qty` | Decimal | Total filled quantity |
| `leaves_qty` | Decimal | Remaining quantity |
| `status` | atom | Current lifecycle state |
| `post_only` | boolean | Post-only flag |
| `close` | boolean | Close position flag |

### Tai.Markets.Quote

Live top-of-book snapshot for a product.

| Field | Type | Description |
|---|---|---|
| `venue_id` | atom | Source venue |
| `product_symbol` | atom | Product identifier |
| `bids` | list(PricePoint) | Bid levels, best first |
| `asks` | list(PricePoint) | Ask levels, best first |
| `last_received_at` | DateTime | Timestamp of last update |

### Tai.Markets.PricePoint

Single price level in an order book.

| Field | Type | Description |
|---|---|---|
| `price` | Decimal | Price at this level |
| `size` | Decimal | Aggregate size at this level |

### Tai.Markets.Trade

Individual trade event from a venue.

| Field | Type | Description |
|---|---|---|
| `id` | string | Trade identifier |
| `venue` | atom | Source venue |
| `product_symbol` | atom | Product traded |
| `price` | Decimal | Execution price |
| `qty` | Decimal | Execution quantity |
| `side` | atom | Aggressor side |
| `liquidation` | boolean | Whether trade was a liquidation |
| `received_at` | DateTime | Local receipt time |
| `venue_timestamp` | DateTime | Exchange timestamp |

### Tai.Trading.Position

Derivative position tracking.

| Field | Type | Description |
|---|---|---|
| `venue_id` | atom | Venue holding the position |
| `credential_id` | atom | Credential owning the position |
| `product_symbol` | atom | Instrument |
| `side` | atom | `:long` or `:short` |
| `qty` | Decimal | Position size |
| `entry_price` | Decimal | Average entry price |
| `leverage` | Decimal | Leverage multiplier |
| `margin_mode` | atom | `:cross` or `:isolated` |

### Tai.Venues.Account

Balance snapshot for a credential on a venue.

| Field | Type | Description |
|---|---|---|
| `venue_id` | atom | Venue |
| `credential_id` | atom | Credential |
| `asset` | atom | Asset symbol |
| `type` | atom | Account type |
| `equity` | Decimal | Total equity |
| `free` | Decimal | Available balance |
| `locked` | Decimal | Locked/reserved balance |

### Tai.Venues.FeeInfo

Fee schedule for a credential and product.

| Field | Type | Description |
|---|---|---|
| `venue_id` | atom | Venue |
| `credential_id` | atom | Credential |
| `symbol` | atom | Product symbol |
| `maker` | Decimal | Maker fee rate |
| `taker` | Decimal | Taker fee rate |

### Tai.Fleets.FleetConfig

Defines a fleet of advisors to instantiate.

| Field | Type | Description |
|---|---|---|
| `id` | atom | Fleet identifier |
| `advisor` | module | Advisor module to run |
| `factory` | module | Factory for spawning instances |
| `market_streams` | map | Venue/product subscriptions |
| `config` | map | Custom advisor configuration |
| `start_on_boot` | boolean | Auto-start flag |

### Tai.Fleets.AdvisorConfig

Per-instance advisor configuration generated by a fleet factory.

| Field | Type | Description |
|---|---|---|
| `advisor_id` | atom | Unique advisor instance ID |
| `fleet_id` | atom | Parent fleet |
| `market_stream_keys` | list | Subscribed market stream keys |
| `config` | map | Merged configuration |
| `mod` | module | Advisor module |

## Event Types (38 total)

All events live in the `Tai.Events` namespace. They are published to the system bus and consumed by `Tai.EventsLogger` and any other subscribers.

### Boot Events
- `BootAdvisors` — Fleet advisors started successfully
- `BootAdvisorsError` — Fleet advisor start failed

### Venue Events
- `VenueStart` — Venue initialized and streams connected
- `VenueStartError` — Venue failed to start
- `VenueStop` — Venue stopped

### Stream Events
- `StreamConnect` — WebSocket connection established
- `StreamDisconnect` — WebSocket disconnected
- `StreamTerminate` — WebSocket process terminated
- `StreamError` — WebSocket error
- `StreamAuthOk` — WebSocket authentication succeeded
- `StreamSubscribeOk` — Channel subscription confirmed
- `StreamChannelInvalid` — Subscription to invalid channel
- `StreamMessageUnhandled` — Received unrecognized message
- `StreamMessageOrderUpdateUnhandled` — Unhandled order update message
- `StreamMessageInvalidOrderClientId` — Order update with unparseable client ID

### Order Events
- `OrderUpdated` — Order state transition applied
- `OrderUpdateInvalidStatus` — Transition rejected due to invalid current status
- `OrderUpdateNotFound` — Transition for nonexistent order

### Advisor Events
- `AdvisorHandleMarketQuoteError` — Exception in `handle_market_quote` callback
- `AdvisorHandleMarketQuoteInvalidReturn` — Bad return value from quote handler
- `AdvisorHandleTradeError` — Exception in `handle_trade` callback
- `AdvisorHandleTradeInvalidReturn` — Bad return value from trade handler

### Hydration Events
- `HydrateProducts` — Products loaded from venue
- `HydrateAccounts` — Account balances loaded
- `HydratePositions` — Positions loaded

### Derivative Events
- `Settlement` — Contract settlement occurred
- `Funding` — Funding rate applied
- `PositionUpdate` — Position changed
- `InsertLiquidation` — Liquidation order inserted
- `UpdateLiquidationPrice` — Liquidation price updated
- `UpdateLiquidationLeavesQty` — Liquidation remaining qty updated
- `DeleteLiquidation` — Liquidation order removed

### Monitoring Events
- `ConnectedStats` — Periodic connection statistics
- `BitmexStreamConnectionLimitDetails` — BitMEX rate limit info

### Trade Events
- `Trade` — Market trade observed
