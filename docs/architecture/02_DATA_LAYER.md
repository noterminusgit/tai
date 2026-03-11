# Data Layer

## Ecto Persistence

### Database Backend

The `OrderRepo` uses SQLite3 by default. PostgreSQL is supported by setting the `DATABASE_URL` environment variable.

### Schemas

#### Order

Primary table for order lifecycle tracking.

- **Primary key**: `client_id` (UUID, client-generated)
- **Fields**: 20+ columns covering venue, credential, product, side, type, time_in_force, price, qty, cumulative_qty, leaves_qty, status, post_only, close, venue_order_id, and timestamps
- **Indexes**: status, venue + credential, product_symbol

#### OrderTransition

Audit log of every state change applied to an order.

- **Primary key**: UUID
- **Foreign key**: `order_client_id` references Order
- **Key field**: `transition` — a `PolymorphicEmbed` column that stores one of 20 different transition types in a single table. Each transition type carries its own set of attributes relevant to that state change.

The `PolymorphicEmbed` approach avoids a table-per-transition-type schema. All 20 transition structs serialize into the same `transition` JSONB/JSON column, with a type discriminator for deserialization.

#### FailedOrderTransition

Records transitions that could not be applied (e.g., optimistic lock failures, invalid status transitions). Same structure as `OrderTransition` but serves as a dead-letter table for debugging.

### Migration Strategy

Migrations are generated, not hand-written:

```bash
# Generate migrations from the tai library's schema definitions
mix tai.gen.migration

# Apply migrations
mix ecto.migrate
```

This ensures migrations stay in sync when the tai dependency is upgraded. After upgrading tai, always re-run `mix tai.gen.migration` followed by `mix ecto.migrate`.

## ETS Stores

All ETS-backed stores use the `Stored` library, which provides a consistent interface for in-memory key-value storage with composite keys.

| Store | Contents | Key Structure |
|---|---|---|
| `Tai.Venues.ProductStore` | Tradeable instruments | `{venue_id, symbol}` |
| `Tai.Venues.FeeStore` | Fee schedules | `{venue_id, credential_id, symbol}` |
| `Tai.Venues.AccountStore` | Account balances | `{venue_id, credential_id, asset}` |
| `Tai.Venues.VenueStore` | Venue runtime state | `{venue_id}` |
| `Tai.Markets.QuoteStore` | Live order book tops | `{venue_id, product_symbol}` |
| `Tai.Trading.PositionStore` | Open positions | `{venue_id, credential_id, product_symbol}` |

Additional stores used internally:

| Store | Contents | Key Structure |
|---|---|---|
| `Tai.Orders.OrderCallbackStore` | Pending order callbacks | `{client_id}` |
| `Tai.Fleets.FleetConfigStore` | Fleet configurations | `{fleet_id}` |
| `Tai.Fleets.AdvisorConfigStore` | Advisor instance configs | `{advisor_id}` |

### Stored.Item Protocol

Each store's value struct implements the `Stored.Item` protocol, which defines how composite keys are extracted from structs. This allows the `Stored` library to automatically derive lookup keys without store-specific code.

## Data Flow

```
Exchange REST API
    │
    ▼
Venue Adapter (products/accounts/fees/positions)
    │
    ▼
ETS Stores (fast reads, process-safe)

Exchange WebSocket
    │
    ▼
Stream Connection (Fresh)
    │
    ├──▶ QuoteStore (order book updates)
    ├──▶ SystemBus (trade events, position updates)
    └──▶ Orders pipeline (venue order updates)
              │
              ▼
         Ecto (Order + OrderTransition)
```

Reads from ETS stores are lock-free and can happen from any process. Writes go through the store's owning process to maintain consistency. Order mutations always go through Ecto transactions with optimistic locking on the order status field.
