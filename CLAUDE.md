# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Tai is a composable, real-time market data and trade execution toolkit for cryptocurrency trading, built with Elixir and running on the Erlang VM. It provides a uniform API for streaming market data and executing trades across multiple cryptocurrency exchanges (venues).

This is an Elixir umbrella project (monorepo) with two main applications:
- `apps/tai` - Core trading toolkit library
- `apps/examples` - Example trading advisors demonstrating tai usage

## Development Commands

### Initial Setup
```bash
# Install dependencies, create database, generate and run migrations
mix setup

# Or step by step:
mix deps.get
mix tai.gen.migration
mix ecto.create
mix ecto.migrate
```

### Running the Application
```bash
# Start application with interactive Elixir shell (imports tai IEx helpers)
iex -S mix

# Start named node for clustering
iex --sname nodename -S mix
```

### Testing
```bash
# Run all tests (automatically creates and migrates test database)
mix test

# Run tests in watch mode
mix test.watch

# Run specific test file
mix test apps/tai/test/tai/orders_test.exs

# Run specific test by line number
mix test apps/tai/test/tai/orders_test.exs:42

# Run tests with coverage
mix coveralls
mix coveralls.html
```

### Code Quality
```bash
# Format code
mix format

# Type checking with Dialyzer
mix dialyzer

# Check licenses
mix licensir
```

### Database Operations
```bash
# Generate new tai migrations (after upgrading tai version)
mix tai.gen.migration

# Reset database
mix ecto.reset

# Run migrations
mix ecto.migrate
```

### Upgrading Tai
When upgrading the tai dependency:
1. Update version in `mix.exs`
2. Run `mix deps.update tai`
3. Run `mix tai.gen.migration` to regenerate migrations
4. Run `mix ecto.migrate` to apply new migrations

## IEx Commands

When running `iex -S mix`, these helper commands are available (imported from `Tai.IEx`):

- `help` - Display available commands
- `venues` - List configured venues and their status
- `products` - List available trading products
- `accounts` - Show account balances
- `fees` - Display maker/taker fees
- `markets` - Show live order book tops
- `orders` - Display order details
- `advisors` - List advisors with optional filters
- `start_venue :venue_id` - Start a venue
- `stop_venue :venue_id` - Stop a venue
- `start_advisors [where: [...]]` - Start advisors with optional filter
- `stop_advisors [where: [...]]` - Stop advisors with optional filter
- `settings` - Display runtime settings
- `enable_send_orders` - Enable actual order transmission to venues
- `disable_send_orders` - Disable order transmission (safety mode)

The `send_orders` flag is a critical safety feature. When `false` (default in dev), orders are enqueued but not transmitted to exchanges, preventing accidental live trading during development.

## Architecture

### Core Concepts

**Advisors**: GenServers that implement the `Tai.Advisor` behavior. They subscribe to market data streams (quotes, trades) and execute trading strategies. Advisors receive callbacks for:
- `after_start/1` - Initialization after startup
- `handle_market_quote/2` - Process order book updates
- `handle_trade/2` - Process trade events
- `on_terminate/2` - Cleanup on shutdown

**Venues**: Exchange adapters implementing the `Tai.Venues.Adapter` behavior. Each venue adapter provides:
- Product fetching (`products/1`)
- Account balance retrieval (`accounts/2`)
- Fee information (`maker_taker_fees/2`)
- Position management for derivatives (`positions/2`)
- Order operations (`create_order/2`, `cancel_order/2`, `amend_order/2`, `amend_bulk_orders/3`)
- Real-time streaming via WebSocket connections

**Fleets**: Collections of advisors configured with a factory pattern. Fleet configuration specifies:
- Advisor module to instantiate
- Factory (e.g., `Tai.Advisors.Factories.OnePerProduct` creates one advisor per product)
- Market streams to subscribe to

**Orders**: Persistent order records managed through Ecto. Order lifecycle states: `enqueued` → `open` → `partially_filled` → `filled` or `cancelled`

**Market Streams**: Real-time order book and trade data from venues, distributed via the system bus (event pub/sub)

### Key Modules

- `apps/tai/lib/tai/advisor.ex` - Advisor behavior and GenServer implementation
- `apps/tai/lib/tai/venues/` - Venue management and instance tracking
- `apps/tai/lib/tai/venue_adapters/` - Exchange-specific adapter implementations
- `apps/tai/lib/tai/orders/` - Order management and persistence
- `apps/tai/lib/tai/commander.ex` - Command interface for controlling venues/advisors
- `apps/tai/lib/tai/system_bus.ex` - Event pub/sub system
- `apps/tai/lib/tai/iex.ex` - IEx helper commands

### Configuration

Configuration uses standard Elixir config files:
- `config/runtime.exs` - Runtime configuration (venues, fleets, database)
- `config/dev.exs.example` - Example development configuration

Key configuration options:
- `:venues` - Map of venue configurations (adapter, products, credentials, market_streams)
- `:fleets` - Map of advisor fleet configurations
- `:send_orders` - Boolean flag to enable/disable actual order transmission
- `:broadcast_change_set` - Boolean to broadcast order book changes to system bus

Secrets are managed via `confex` library, supporting environment variables and file system reads with `{:system_file, "VAR_NAME"}` syntax.

### Creating Venue Adapters

To add support for a new exchange:

1. Create or use an existing Elixir HTTP client library for the exchange
2. Copy the stub adapter structure:
   - `apps/tai/lib/tai/venue_adapters/stub.ex`
   - `apps/tai/lib/tai/venue_adapters/stub/stream_supervisor.ex`
   - `apps/tai/lib/tai/venue_adapters/stub/stream/connection.ex`
3. Implement required callbacks:
   - `products/1` - Fetch available products
   - `accounts/2` - Retrieve balances
   - `maker_taker_fees/2` - Fetch fee structure
   - `positions/2` - Get positions (derivatives only)
   - `create_order/2`, `cancel_order/2`, `amend_order/2` - Order operations
4. Implement WebSocket stream connection for real-time market data
5. Configure venue in `config/runtime.exs`

## Test Structure

Tests follow standard Elixir/ExUnit patterns:
- Test files end with `_test.exs`
- Located in `apps/tai/test/` or alongside modules in `apps/tai/lib/tai/events/*_test.exs`
- Use `ExUnit.Case` for test cases
- The test alias automatically sets up the test database before running

## Clustering

Tai supports distributed Erlang clustering. The `Tai.Commander` module accepts a `node: :nodename` option on all commands to control remote nodes. This enables managing multiple tai instances across a cluster from a single IEx session.

Example: `Tai.Commander.venues(node: :"other_node@host")` returns venues from the remote node.
