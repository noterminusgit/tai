# System Overview

## Project Structure

Tai is an Elixir umbrella project (monorepo) for composable, real-time cryptocurrency market data and trade execution. It requires Elixir 1.14+ and OTP 25+.

### Umbrella Applications

| Application | Path | Purpose |
|---|---|---|
| `tai` | `apps/tai` | Core trading toolkit library |
| `examples` | `apps/examples` | Example trading advisors demonstrating tai usage |

### Packages

| Package | Purpose |
|---|---|
| `tai_events` | Event logging and structured event definitions |

## Technology Stack

| Concern | Library |
|---|---|
| HTTP | Req |
| WebSocket | Fresh |
| Persistence | Ecto (SQLite3 default, PostgreSQL supported) |
| Messaging | Phoenix.PubSub |
| ETS Storage | Stored |
| Schema Flexibility | PolymorphicEmbed |

## Supervision Tree

The top-level `Tai.Application` supervisor starts 17 children under a `:one_for_one` strategy. Children are grouped by responsibility below, listed in start order.

### Core Infrastructure

| Child | Type | Description |
|---|---|---|
| `Phoenix.PubSub` (`:Tai.PubSub`) | PubSub | Cluster-aware pub/sub backbone |
| `Tai.SystemBus` | Registry | Registry-based event routing for fine-grained topic subscriptions |
| `Tai.EventsLogger` | GenServer | Subscribes to the system bus and logs structured events |
| `Tai.Settings` | GenServer | Runtime settings (e.g., `send_orders` flag) |

### Storage Layer

| Child | Type | Backing |
|---|---|---|
| `Tai.Trading.PositionStore` | Stored | ETS |
| `Tai.Orders.Supervisor` | Supervisor | Ecto (SQLite3/PostgreSQL) |
| `Tai.Markets.QuoteStore` | Stored | ETS |
| `Tai.Venues.Telemetry` | GenServer | Telemetry metrics |
| `Tai.Venues.ProductStore` | Stored | ETS |
| `Tai.Venues.FeeStore` | Stored | ETS |
| `Tai.Venues.AccountStore` | Stored | ETS |
| `Tai.Venues.VenueStore` | Stored | ETS |

### Dynamic Supervisors

| Child | Type | Description |
|---|---|---|
| `Tai.Venues.StreamsSupervisor` | DynamicSupervisor | WebSocket stream connections per venue |
| `Tai.Venues.Supervisor` | DynamicSupervisor | Venue instance lifecycle management |
| `Tai.Advisors.Supervisor` | DynamicSupervisor | Running advisor processes |
| `Tai.Fleets.Supervisor` | DynamicSupervisor | Fleet orchestration |

### Control Plane

| Child | Type | Description |
|---|---|---|
| `Tai.Commander` | GenServer | Command interface for venues, advisors, and system control |
| `Tai.Boot` | GenServer | Orchestrates startup phases |

## Boot Sequence

`Tai.Boot` is a GenServer that runs initialization phases after the supervision tree is up:

1. **`:venues` phase** — Iterates configured venues and starts those with `start_on_boot: true`. Each venue start hydrates products, accounts, fees, and positions from the exchange, then opens WebSocket streams for subscribed market data channels.

After the venues phase completes, fleets with `start_on_boot: true` are also initialized, spawning advisor processes according to their factory configuration.
