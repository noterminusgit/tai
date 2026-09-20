# Architecture

[Getting Started](./GETTING_STARTED.md) | [Built with Tai](./BUILT_WITH_TAI.md) | [Commands](./COMMANDS.md) | [Architecture](./ARCHITECTURE.md) | [Examples](../apps/examples/README.md) | [Configuration](./CONFIGURATION.md) | [Observability](./OBSERVABILITY.md)

## Overview

Tai is a composable, real-time market data and trade execution toolkit built on Elixir/OTP. It provides a uniform API across 9 cryptocurrency exchanges with careful attention to concurrency, reliability, and operational safety.

For detailed architecture documentation, see the `docs/architecture/` directory:

| Document | Description |
|----------|-------------|
| [00 System Overview](./architecture/00_SYSTEM_OVERVIEW.md) | Umbrella structure, supervision tree, tech stack |
| [01 Domain Model](./architecture/01_DOMAIN_MODEL.md) | Core structs, relationships, 38 event types |
| [02 Data Layer](./architecture/02_DATA_LAYER.md) | Ecto schemas, ETS stores, migration strategy |
| [03 Functional Core](./architecture/03_FUNCTIONAL_CORE.md) | Order state machine (20 transitions) |
| [04 Boundaries](./architecture/04_BOUNDARIES.md) | Commander, Client, Adapter, SystemBus |
| [05 Lifecycle](./architecture/05_LIFECYCLE.md) | Boot sequence, venue start, WebSocket, advisors |
| [06 Workers](./architecture/06_WORKERS.md) | Order worker pool, transition workers |
| [07 Integration Patterns](./architecture/07_INTEGRATION_PATTERNS.md) | Venue adapters, WebSocket streams, order book pipeline |

## Orders

![Order States](./architecture/order-states.png)

The order state machine supports 20 transition types across creation, active trading, cancellation, amendment, and terminal phases. See [03 Functional Core](./architecture/03_FUNCTIONAL_CORE.md) for the complete transition map.

## Advisors

Advisors are the brains of any `tai` application, they subscribe to changes in
market data to record and analyze data or execute automated trading strategies.

Orders are created and managed through a uniform API across exchanges, with
fast execution and reliability.

Take a look at some of the [examples](../apps/examples) to understand what
you can create with advisors.

## Decision Records

Architecture Decision Records (ADRs) are in `docs/decisions/`:

- [ADR-001: Baseline Metrics](./decisions/ADR-001-baseline-metrics.md)
- [ADR-002: Order State Machine](./decisions/ADR-002-order-state-machine.md)
- [ADR-003: Venue Adapter Pattern](./decisions/ADR-003-venue-adapter-pattern.md)
- [ADR-004: ETS Stores](./decisions/ADR-004-ets-stores.md)
