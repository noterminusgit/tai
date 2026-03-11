# Integration Patterns

This document describes how Tai integrates with external exchanges (venues) and how market data flows from WebSocket connections to trading advisors.

## Venue Adapter Pattern

Each exchange integration implements the `Tai.Venues.Adapter` behavior. The adapter contract defines callbacks for products, accounts, fees, positions, and order operations.

- Adapters that do not support a particular operation return `:not_implemented`.
- Reference implementation: `apps/tai/lib/tai/venue_adapters/stub.ex`

### Available Adapters

Tai includes 11 venue adapters:

| Adapter | Description |
|---|---|
| Binance | Binance spot and futures |
| BitMEX | BitMEX derivatives |
| Bybit | Bybit derivatives |
| Deribit | Deribit options and futures |
| DeltaExchange | Delta Exchange derivatives |
| Gdax | Coinbase Pro (GDAX) |
| Huobi | Huobi Global |
| Kraken | Kraken spot |
| OkEx | OKEx spot and derivatives |
| Mock | In-memory mock for testing |
| Stub | Minimal stub for reference and development |

## WebSocket Stream Architecture

Each venue adapter provides a streaming subsystem composed of two modules:

- **StreamSupervisor** — Supervises WebSocket connection processes for the venue.
- **Connection** — Implements the WebSocket connection using the `use Tai.Venues.Streams.ConnectionAdapter` macro, which wraps the Fresh WebSocket library.

The stream supervisor starts connections with:
- Venue configuration (credentials, endpoints).
- The list of products to subscribe to.
- Account information for authenticated streams.

## Order Book Pipeline

Market data flows through the following pipeline:

1. **WebSocket message** — Raw frame arrives from the exchange.
2. **Connection.handle_in** — The adapter's connection module receives and parses the frame.
3. **OrderBook.replace/apply** — Parsed data updates the local order book (full snapshot replace or incremental apply).
4. **QuoteStore.put** — The best bid/ask (top of book) is stored in the QuoteStore.
5. **Phoenix.PubSub broadcast** — The updated quote is broadcast to subscribers.
6. **Advisor receives via handle_info** — Subscribed advisors receive the quote and invoke `handle_market_quote/2`.

## Market Data Flow Summary

```
Venue WebSocket
    |
    v
Adapter Connection (parse + normalize)
    |
    v
Tai Structs (MarketQuote, Trade, etc.)
    |
    v
Phoenix.PubSub
    |
    v
Subscribed Advisors (handle_market_quote/2, handle_trade/2)
```

The normalization step is critical: each adapter translates exchange-specific message formats into uniform Tai structs, ensuring that advisors operate against a consistent data model regardless of which venue they are connected to.
