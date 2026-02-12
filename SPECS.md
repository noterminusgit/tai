# SPECS.md - Tai Technical Specifications

This document provides detailed technical specifications for the Tai cryptocurrency trading toolkit, including module behaviors, type specifications, and API contracts.

## Table of Contents

1. [Overview](#overview)
2. [Core Types](#core-types)
3. [Advisor Behavior](#advisor-behavior)
4. [Venue Adapter Behavior](#venue-adapter-behavior)
5. [Order Management](#order-management)
6. [Market Data](#market-data)
7. [Configuration](#configuration)
8. [System Bus](#system-bus)
9. [Commander API](#commander-api)
10. [Event System](#event-system)

---

## Overview

Tai is a composable, real-time market data and trade execution toolkit built with Elixir. It provides a uniform API for streaming market data and executing trades across multiple cryptocurrency exchanges.

### Architecture Diagram

```
+----------------+     +----------------+     +----------------+
|   Advisors     |     |   Commander    |     |   IEx Helpers  |
| (Trading       |     | (Control       |     | (Interactive   |
|  Strategies)   |     |  Interface)    |     |  Commands)     |
+-------+--------+     +-------+--------+     +-------+--------+
        |                      |                      |
        v                      v                      v
+-------+----------------------+----------------------+--------+
|                         Tai.SystemBus                        |
|                    (Event Pub/Sub System)                    |
+------+-------------------+-------------------+---------------+
       |                   |                   |
       v                   v                   v
+------+------+     +------+------+     +------+------+
|   Markets   |     |   Orders    |     |   Venues    |
| (Quotes &   |     | (Ecto       |     | (Exchange   |
|  Trades)    |     |  Persistence)|    |  Adapters)  |
+-------------+     +-------------+     +-------------+
```

---

## Core Types

### Identifiers

```elixir
@type venue_id :: atom
@type credential_id :: atom
@type product_symbol :: atom
@type client_id :: Ecto.UUID.t()
@type venue_order_id :: String.t()
@type fleet_id :: atom
@type advisor_id :: term
```

### Decimal Values

All monetary and quantity values use `Decimal.t()` for precision:

```elixir
@type price :: Decimal.t()
@type qty :: Decimal.t()
@type fee :: Decimal.t()
```

---

## Advisor Behavior

Advisors are GenServers that implement trading strategies by subscribing to market data streams.

### Module: `Tai.Advisor`

#### Callbacks

```elixir
@callback after_start(state :: Tai.Advisor.State.t()) :: {:ok, run_store :: map}
```
Called after the advisor starts and subscribes to market streams. Use this to initialize strategy state.

```elixir
@callback handle_market_quote(
  market_quote :: Tai.Markets.Quote.t(),
  state :: Tai.Advisor.State.t()
) :: {:ok, run_store :: map}
```
Called when an order book update is received. Process the quote and optionally create/modify orders.

```elixir
@callback handle_trade(
  trade :: Tai.Markets.Trade.t(),
  state :: Tai.Advisor.State.t()
) :: {:ok, run_store :: map}
```
Called when a trade event is received from the market stream.

```elixir
@callback on_terminate(
  reason :: :normal | :shutdown | {:shutdown, term} | term,
  state :: Tai.Advisor.State.t()
) :: term
```
Called when the advisor is shutting down. Use for cleanup operations.

#### State Structure

```elixir
@type t :: %Tai.Advisor.State{
  fleet_id: fleet_id,
  advisor_id: advisor_id,
  config: struct | map,
  store: map,
  market_quotes: Tai.Advisors.MarketMap.t(),
  trades: Tai.Advisors.MarketMap.t()
}
```

#### Usage Example

```elixir
defmodule MyAdvisor do
  use Tai.Advisor

  @impl true
  def after_start(state) do
    {:ok, %{order_count: 0}}
  end

  @impl true
  def handle_market_quote(market_quote, state) do
    # Process quote, potentially create orders
    {:ok, state.store}
  end
end
```

---

## Venue Adapter Behavior

Venue adapters implement exchange-specific functionality for a uniform API.

### Module: `Tai.Venues.Adapter`

#### Required Callbacks

```elixir
@callback stream_supervisor() :: module
```
Returns the module that supervises WebSocket stream connections.

```elixir
@callback products(venue_id) :: {:ok, [product]} | {:error, shared_error_reason}
```
Fetches available trading products from the exchange.

```elixir
@callback accounts(venue_id, credential_id, credentials) ::
  {:ok, [account]} | {:error, shared_error_reason}
```
Retrieves account balances for the given credentials.

```elixir
@callback positions(venue_id, credential_id, credentials) ::
  {:ok, [position]} | {:error, positions_error_reason}
```
Gets open positions (for derivatives venues).

```elixir
@callback maker_taker_fees(venue_id, credential_id, credentials) ::
  {:ok, {maker :: Decimal.t(), taker :: Decimal.t()} | nil} |
  {:error, shared_error_reason}
```
Retrieves the maker/taker fee structure.

```elixir
@callback create_order(order, credentials) ::
  {:ok, create_response} | {:error, create_order_error_reason}
```
Submits a new order to the exchange.

```elixir
@callback amend_order(order, amend_attrs, credentials) ::
  {:ok, amend_response} | {:error, amend_order_error_reason}
```
Modifies an existing order.

```elixir
@callback amend_bulk_orders([{order, amend_attrs}], credentials) ::
  {:ok, amend_bulk_response} | {:error, amend_order_error_reason}
```
Modifies multiple orders in a single request.

```elixir
@callback cancel_order(order, credentials) ::
  {:ok, cancel_response} | {:error, cancel_order_error_reason}
```
Cancels an existing order.

#### Error Types

```elixir
@type shared_error_reason ::
  :not_implemented |
  :timeout |
  :connect_timeout |
  :overloaded |
  :rate_limited |
  {:credentials, reason :: term} |
  {:nonce_not_increasing, String.t()} |
  {:unhandled, reason :: term}

@type positions_error_reason :: shared_error_reason | :not_supported

@type create_order_error_reason ::
  shared_error_reason |
  :size_too_small |
  :insufficient_balance |
  :insufficient_position

@type amend_order_error_reason ::
  shared_error_reason |
  :insufficient_balance |
  :insufficient_position |
  :not_found |
  :not_supported

@type cancel_order_error_reason ::
  shared_error_reason |
  :not_found |
  :already_closed |
  :already_queued_for_cancelation
```

#### Supported Venue Adapters

| Adapter | Module | Spot | Futures | Swap | Options |
|---------|--------|------|---------|------|---------|
| Binance | `Tai.VenueAdapters.Binance` | Yes | Yes | - | - |
| BitMEX | `Tai.VenueAdapters.Bitmex` | - | Yes | Yes | - |
| Bybit | `Tai.VenueAdapters.Bybit` | Yes | Yes | Yes | - |
| Coinbase Pro | `Tai.VenueAdapters.Gdax` | Yes | - | - | - |
| Delta Exchange | `Tai.VenueAdapters.DeltaExchange` | - | Yes | Yes | - |
| Deribit | `Tai.VenueAdapters.Deribit` | - | Yes | Yes | Yes |
| Huobi | `Tai.VenueAdapters.Huobi` | Yes | Yes | - | - |
| Kraken | `Tai.VenueAdapters.Kraken` | Yes | - | - | - |
| OKEx | `Tai.VenueAdapters.OkEx` | Yes | Yes | Yes | Yes |

---

## Order Management

### Module: `Tai.Orders`

#### Order Structure

```elixir
@type t :: %Tai.Orders.Order{
  client_id: Ecto.UUID.t(),
  venue: String.t(),
  credential: String.t(),
  product_symbol: String.t(),
  venue_product_symbol: String.t(),
  product_type: :spot | :future | :swap | :option,
  side: :buy | :sell,
  type: :limit,
  time_in_force: :gtc | :fok | :ioc,
  status: order_status,
  price: Decimal.t(),
  qty: Decimal.t(),
  leaves_qty: Decimal.t(),
  cumulative_qty: Decimal.t(),
  post_only: boolean,
  close: boolean,
  venue_order_id: String.t() | nil,
  last_received_at: DateTime.t() | nil,
  last_venue_timestamp: DateTime.t() | nil,
  inserted_at: DateTime.t(),
  updated_at: DateTime.t()
}
```

#### Order Status Lifecycle

```
enqueued --> create_accepted --> open --> filled
                |                  |
                v                  v
          create_error      partially_filled --> filled
                                   |
                                   v
                            pending_cancel --> cancel_accepted --> canceled
                                   |
                                   v
                            pending_amend --> amend_accepted --> open
```

Valid statuses:
- `enqueued` - Order created locally, not yet sent to venue
- `create_accepted` - Venue acknowledged order creation
- `create_error` - Order creation failed
- `open` - Order is active on the venue
- `partially_filled` - Order has been partially executed
- `filled` - Order fully executed
- `pending_cancel` - Cancel request sent
- `cancel_accepted` - Venue acknowledged cancel
- `canceled` - Order canceled
- `pending_amend` - Amend request sent
- `amend_accepted` - Venue acknowledged amend
- `expired` - Order expired (time_in_force)
- `rejected` - Order rejected by venue
- `skipped` - Order skipped (send_orders disabled)

#### API Functions

```elixir
@spec create(submission) :: {:ok, order} | {:error, reason}
```
Creates and submits a new order.

```elixir
@spec cancel(order) :: {:ok, order} | {:error, reason}
```
Cancels an existing order.

```elixir
@spec amend(order, amend_attrs) :: {:ok, order} | {:error, reason}
```
Amends an existing order.

```elixir
@spec amend_bulk([{order, amend_attrs}]) :: {:ok, [order]} | {:error, reason}
```
Amends multiple orders in bulk.

```elixir
@spec search(query, opts) :: [order]
```
Searches orders with optional pagination.

```elixir
@spec get_by_client_id(client_id) :: order | nil
```
Retrieves an order by its client ID.

---

## Market Data

### Market Quote

```elixir
@type t :: %Tai.Markets.Quote{
  venue_id: venue_id,
  product_symbol: product_symbol,
  bids: [price_point],
  asks: [price_point],
  last_received_at: integer,
  last_venue_timestamp: DateTime.t() | nil
}

@type price_point :: %Tai.Markets.PricePoint{
  price: Decimal.t(),
  size: Decimal.t()
}
```

#### Quote Functions

```elixir
@spec inside_bid(quote) :: price_point | nil
@spec inside_ask(quote) :: price_point | nil
@spec mid_price(quote) :: {:ok, Decimal.t()} | {:error, :no_inside_bid | :no_inside_ask}
```

### Market Trade

```elixir
@type t :: %Tai.Markets.Trade{
  venue: venue_id,
  product_symbol: product_symbol,
  price: Decimal.t(),
  qty: Decimal.t(),
  side: :buy | :sell,
  venue_timestamp: DateTime.t(),
  received_at: integer
}
```

### Subscription

```elixir
# Subscribe to all quotes
Tai.Markets.subscribe_quote("*")

# Subscribe to venue quotes
Tai.Markets.subscribe_quote(:binance)

# Subscribe to specific product
Tai.Markets.subscribe_quote({:binance, :btc_usdt})

# Same patterns for trades
Tai.Markets.subscribe_trade("*")
Tai.Markets.subscribe_trade(:binance)
Tai.Markets.subscribe_trade({:binance, :btc_usdt})
```

---

## Configuration

### Module: `Tai.Config`

```elixir
@type t :: %Tai.Config{
  adapter_timeout: pos_integer,          # Default: 10_000ms
  after_boot: mfa | nil,                 # Handler called after successful boot
  after_boot_error: mfa | nil,           # Handler called after boot error
  broadcast_change_set: boolean,         # Default: false
  fleets: map,                           # Fleet configurations
  logger: module,                        # Custom logger module
  order_workers: pos_integer,            # Default: 5
  order_workers_max_overflow: non_neg_integer,  # Default: 2
  order_transition_workers: pos_integer, # Default: 5
  send_orders: boolean,                  # Default: false (safety)
  system_bus_registry_partitions: pos_integer,
  venues: map                            # Venue configurations
}
```

### Venue Configuration

```elixir
config :tai, venues: %{
  binance: [
    start_on_boot: true,
    adapter: Tai.VenueAdapters.Binance,
    products: "btc_usdt eth_usdt",  # or "*" for all
    market_streams: "btc_usdt",     # or "*" for all
    credentials: %{
      main: %{
        api_key: {:system_file, "BINANCE_API_KEY"},
        secret_key: {:system_file, "BINANCE_API_SECRET"}
      }
    },
    quote_depth: 1,                 # Order book depth
    timeout: 10_000,                # Request timeout
    stream_heartbeat_interval: 5_000,
    stream_heartbeat_timeout: 10_000
  ]
}
```

### Fleet Configuration

```elixir
@type t :: %Tai.Fleets.FleetConfig{
  id: atom,
  start_on_boot: boolean,
  restart: :permanent | :transient | :temporary,
  shutdown: timeout | :brutal_kill,
  market_streams: String.t(),
  factory: module,
  advisor: module,
  config: struct | map
}
```

```elixir
config :tai, fleets: %{
  my_strategy: %{
    advisor: MyApp.Advisor,
    factory: Tai.Advisors.Factories.OnePerProduct,
    market_streams: "binance.btc_usdt binance.eth_usdt",
    config: %{custom_param: "value"}
  }
}
```

#### Advisor Factories

| Factory | Description |
|---------|-------------|
| `Tai.Advisors.Factories.OnePerProduct` | Creates one advisor per product in market_streams |
| `Tai.Advisors.Factories.OnePerVenue` | Creates one advisor per venue |
| `Tai.Advisors.Factories.OneForAllProducts` | Creates a single advisor for all products |

---

## System Bus

### Module: `Tai.SystemBus`

The system bus is a core pub/sub mechanism using Elixir's Registry.

```elixir
@type topic :: atom | tuple
@type topics :: [topic]

@spec subscribe(topic | topics) :: :ok
@spec unsubscribe(topic | topics) :: :ok
@spec broadcast(topic, term) :: :ok
```

### Reserved Topics

- Boot events
- Stream connection events
- Product/account/position hydration
- Order book changesets
- Metrics

---

## Commander API

### Module: `Tai.Commander`

The Commander provides a unified interface for querying and controlling the system, with support for distributed nodes via the `node: :nodename` option.

#### Venue Operations

```elixir
@spec venues(options) :: [venue_status]
@spec start_venue(venue_id, options) :: :ok | {:error, reason}
@spec stop_venue(venue_id, options) :: :ok | {:error, reason}
```

#### Product & Account Queries

```elixir
@spec products(options) :: [product]
@spec accounts(options) :: [account]
@spec fees(options) :: [fee_info]
@spec positions(options) :: [position]
@spec markets(options) :: [market_quote]
```

#### Order Operations

```elixir
@spec orders(query, options) :: [order]
@spec orders_count(query, options) :: non_neg_integer
@spec get_order_by_client_id(client_id, options) :: order | nil
@spec get_orders_by_client_ids([client_id], options) :: [order]
@spec order_transitions(client_id, query, options) :: [transition]
@spec delete_all_orders(options) :: {count, nil}
```

#### Advisor Operations

```elixir
@spec fleets(options) :: [fleet_config]
@spec advisors(options) :: [advisor_status]
@spec start_advisors(options) :: {:ok, started_count}
@spec stop_advisors(options) :: {:ok, stopped_count}
```

#### Settings

```elixir
@spec settings(options) :: settings
@spec enable_send_orders(options) :: :ok
@spec disable_send_orders(options) :: :ok
```

---

## Event System

Tai uses structured events for logging and monitoring.

### Event Categories

#### Stream Events
- `Tai.Events.StreamConnect` - WebSocket connected
- `Tai.Events.StreamDisconnect` - WebSocket disconnected
- `Tai.Events.StreamError` - Stream error occurred
- `Tai.Events.StreamSubscribeOk` - Channel subscription successful
- `Tai.Events.StreamAuthOk` - Authentication successful
- `Tai.Events.StreamTerminate` - Stream terminated

#### Venue Events
- `Tai.Events.VenueStart` - Venue started
- `Tai.Events.VenueStartError` - Venue failed to start
- `Tai.Events.VenueStop` - Venue stopped

#### Hydration Events
- `Tai.Events.HydrateProducts` - Products loaded
- `Tai.Events.HydrateAccounts` - Accounts loaded
- `Tai.Events.HydratePositions` - Positions loaded

#### Order Events
- `Tai.Events.OrderUpdated` - Order state changed
- `Tai.Events.OrderUpdateNotFound` - Update for unknown order
- `Tai.Events.OrderUpdateInvalidStatus` - Invalid status transition

#### Advisor Events
- `Tai.Events.BootAdvisors` - Advisors started
- `Tai.Events.BootAdvisorsError` - Advisor boot failed
- `Tai.Events.AdvisorHandleMarketQuoteError` - Error in quote handler
- `Tai.Events.AdvisorHandleTradeError` - Error in trade handler

#### Position Events
- `Tai.Events.PositionUpdate` - Position changed
- `Tai.Events.InsertLiquidation` - Liquidation inserted
- `Tai.Events.UpdateLiquidationPrice` - Liquidation price updated
- `Tai.Events.DeleteLiquidation` - Liquidation removed

### Event Structure Pattern

All events follow a consistent structure:

```elixir
defmodule Tai.Events.SomeEvent do
  @type t :: %__MODULE__{
    field1: type1,
    field2: type2
  }

  @enforce_keys ~w[field1 field2]a
  defstruct ~w[field1 field2]a
end
```

---

## Runtime Settings

### Module: `Tai.Settings`

Runtime settings are stored in ETS for fast access.

```elixir
@type t :: %Tai.Settings{
  send_orders: boolean
}

@spec send_orders?(id \\ :default) :: boolean
@spec enable_send_orders!(id \\ :default) :: :ok
@spec disable_send_orders!(id \\ :default) :: :ok
@spec all(id \\ :default) :: t
```

The `send_orders` flag is a critical safety feature:
- When `false` (default in dev): Orders are enqueued but not transmitted
- When `true`: Orders are transmitted to venues

---

## Product Types

### Tai.Venues.Product

```elixir
@type t :: %Tai.Venues.Product{
  venue_id: venue_id,
  symbol: atom,
  venue_symbol: String.t(),
  alias: String.t() | nil,
  base: asset,
  quote: asset,
  venue_base: String.t(),
  venue_quote: String.t(),
  status: product_status,
  type: :spot | :future | :swap | :option | :leveraged_token,
  listing: DateTime.t() | nil,
  expiry: DateTime.t() | nil,
  collateral: boolean,
  collateral_weight: Decimal.t() | nil,
  price_increment: Decimal.t(),
  size_increment: Decimal.t(),
  min_price: Decimal.t(),
  min_size: Decimal.t(),
  min_notional: Decimal.t() | nil,
  max_price: Decimal.t() | nil,
  max_size: Decimal.t() | nil,
  value: Decimal.t(),
  value_side: :base | :quote,
  is_quanto: boolean,
  is_inverse: boolean,
  maker_fee: Decimal.t() | nil,
  taker_fee: Decimal.t() | nil,
  strike: Decimal.t() | nil,
  option_type: :call | :put | nil
}

@type product_status ::
  :unknown |
  :pre_trading |
  :trading |
  :restricted |
  :post_trading |
  :end_of_day |
  :halt |
  :auction_match |
  :break |
  :settled |
  :delisted
```

---

## Clustering

Tai supports distributed Erlang clustering. Use the `node:` option with Commander functions:

```elixir
# Query venues on remote node
Tai.Commander.venues(node: :"other@host")

# Start venue on remote node
Tai.Commander.start_venue(:binance, node: :"other@host")

# Get settings from remote node
Tai.Commander.settings(node: :"other@host")
```

---

## Testing

### Test Database

Tests automatically create and migrate the test database.

```bash
# Run all tests
mix test

# Run specific test file
mix test apps/tai/test/tai/orders_test.exs

# Run specific test by line
mix test apps/tai/test/tai/orders_test.exs:42

# Run with coverage
mix coveralls
```

### Mock Adapter

Use `Tai.VenueAdapters.Mock` for testing:

```elixir
config :tai, venues: %{
  mock: [
    adapter: Tai.VenueAdapters.Mock,
    credentials: %{main: %{}}
  ]
}
```

---

## Version History

| Version | Date | Description |
|---------|------|-------------|
| 1.0.0 | 2026-02-11 | Initial SPECS.md creation |
