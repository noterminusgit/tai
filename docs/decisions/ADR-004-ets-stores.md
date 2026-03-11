# ADR-004: ETS Stores for Runtime Data

- **Date:** 2026-03-11
- **Status:** Accepted

## Context

Tai's core loop — streaming market data, evaluating advisor logic, and submitting orders — is latency-sensitive. The system needs sub-millisecond reads for reference data such as products, fees, account balances, order book quotes, and advisor configuration. At the same time, certain data (orders and their transitions) must survive process and node restarts. The system must balance:

- Read performance under high concurrency (many advisors reading product and quote data simultaneously).
- Data durability for audit-critical records (order history).
- Startup simplicity — reference data is always available from the venues themselves and does not need to survive restarts.

## Decision

### ETS tables for fast concurrent runtime reads

The following data is stored in ETS tables, each wrapped by a dedicated store module:

| Store Module | Contents |
|---|---|
| `ProductStore` | Tradeable products fetched during venue boot |
| `FeeStore` | Maker/taker fee schedules per venue and product |
| `AccountStore` | Account balances, updated by venue streams |
| `VenueStore` | Venue runtime status and metadata |
| `QuoteStore` | Latest best-bid/best-ask snapshots per product |
| `OrderCallbackStore` | Callbacks registered for order state changes |
| `FleetConfigStore` | Fleet (advisor group) configuration |
| `AdvisorConfigStore` | Per-advisor configuration and state |
| `PositionStore` | Open derivative positions |

Each store module exposes a public API (e.g., `ProductStore.find/1`, `FeeStore.upsert/1`) that wraps raw `:ets` calls. Callers never interact with ETS table names or match specs directly. Tables use `read_concurrency: true` where applicable.

### Ecto and PostgreSQL for persistent order data

Orders and order transitions are stored in PostgreSQL via Ecto. These records must survive node restarts for auditability, reconciliation, and recovery. The `orders` and `order_transitions` tables are the system of record for trade history.

### Initialization on application start, populated during venue boot

All ETS tables are created during application startup by their respective store modules (or a top-level supervisor). Tables start empty. When a venue boots (see ADR-003), the two-phase initialization process populates the relevant stores:

1. Products fetched from the venue are inserted into `ProductStore`.
2. Fees are inserted into `FeeStore`.
3. Account balances are inserted into `AccountStore`.
4. Positions are inserted into `PositionStore`.
5. Once the WebSocket stream is running, `QuoteStore` is continuously updated with live quotes.

This means that after a node restart, ETS data is unavailable until venues have finished their boot sequence. No attempt is made to persist or snapshot ETS data to disk.

### Public API modules as the access boundary

Each store module serves as the sole access point for its data. This provides:

- A stable API that can be changed without affecting callers if the underlying storage mechanism changes.
- A natural place for input validation, key normalization, and event broadcasting on writes.
- Clear ownership — each store module owns exactly one ETS table.

## Consequences

### Positive

- **Sub-microsecond reads.** ETS `read_concurrency` tables deliver consistent low-latency lookups regardless of the number of concurrent advisor processes reading product or quote data.
- **No network round-trip for hot-path data.** Advisors processing market quotes do not need to query a database or call through a GenServer bottleneck.
- **Simple mental model.** Ephemeral runtime data lives in ETS; durable trade records live in PostgreSQL. There is no ambiguity about where to look.
- **Clean restart semantics.** ETS data is always rebuilt from the authoritative source (the venues). There is no stale-cache invalidation problem.

### Negative

- **Data loss on restart.** All ETS data is lost when the node stops. The system is unavailable for trading until all venues have completed their boot sequence. For venues with slow APIs, this can take tens of seconds.
- **No cross-node sharing.** ETS tables are local to a single BEAM node. In a clustered deployment, each node maintains its own copy of venue data. There is no built-in synchronization between nodes.
- **Memory pressure.** Large product catalogs or high-frequency quote updates consume BEAM memory. There are no built-in eviction or compaction mechanisms for the ETS stores.
- **Dual-storage complexity.** Developers must understand which data lives in ETS versus PostgreSQL. Misplacing data (e.g., writing audit-critical information only to ETS) would create a silent durability gap.
