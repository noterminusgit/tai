# Tai Project Handoff Document

This document provides a complete orientation for AI agents (Director/Implementor roles) or human developers working on the Tai codebase.

## Project Map

```
tai/                              # Elixir umbrella project root
├── apps/
│   ├── tai/                      # Core trading toolkit library
│   │   ├── lib/tai/
│   │   │   ├── advisor.ex        # Advisor behavior (GenServer macro)
│   │   │   ├── application.ex    # OTP application, supervision tree
│   │   │   ├── boot.ex           # Boot coordination GenServer
│   │   │   ├── commander.ex      # Public API facade
│   │   │   ├── config.ex         # Configuration parsing
│   │   │   ├── events/           # 38 event struct modules
│   │   │   ├── events_logger.ex  # TaiEvents → Logger bridge
│   │   │   ├── fleets/           # Fleet/advisor config management
│   │   │   ├── iex.ex            # IEx helper commands
│   │   │   ├── markets/          # Quote, Trade, OrderBook, PricePoint
│   │   │   ├── orders/           # Order management, state machine
│   │   │   │   ├── order.ex      # Ecto schema
│   │   │   │   ├── transitions/  # 20 transition modules
│   │   │   │   ├── services/     # EnqueueOrder, ApplyOrderTransition
│   │   │   │   ├── worker.ex     # Async order submission
│   │   │   │   └── order_transition_worker.ex  # Sequential state changes
│   │   │   ├── settings.ex       # Runtime settings (send_orders flag)
│   │   │   ├── system_bus.ex     # Registry-based pub/sub
│   │   │   ├── trading/          # Position management
│   │   │   ├── venue_adapters/   # 11 exchange adapters
│   │   │   └── venues/           # Venue management, Client, Adapter behavior
│   │   └── test/                 # Tests mirror lib/ structure
│   └── examples/                 # Example trading advisors
├── config/
│   └── runtime.exs               # All configuration (dev, test, prod)
├── docs/
│   ├── architecture/             # Detailed architecture docs (8 files)
│   ├── decisions/                # Architecture Decision Records
│   ├── guardrails/               # Safety rules and role definitions
│   ├── design/                   # (Director fills during feature work)
│   ├── plans/                    # (Director creates implementation plans)
│   └── api/                      # (Director documents API contracts)
└── CLAUDE.md                     # AI assistant instructions
```

## How to Run / Test

See `CLAUDE.md` for complete commands. Quick reference:

```bash
mix setup                          # First time setup
iex -S mix                         # Start with IEx
./run_tests.sh                     # Run tests (sets up dummy credentials)
./run_tests.sh apps/tai/test/tai/advisor_test.exs  # Specific test
mix format                         # Format code
mix dialyzer                       # Type checking
```

**Note**: Tests require credential file paths via environment variables for confex. The `run_tests.sh` script handles this automatically with dummy values.

## Architecture Summary

See `docs/architecture/` for detailed documentation:

- **00_SYSTEM_OVERVIEW** — 17-child supervision tree, tech stack
- **01_DOMAIN_MODEL** — All structs, 38 event types
- **02_DATA_LAYER** — Ecto + ETS stores
- **03_FUNCTIONAL_CORE** — Order state machine (20 transitions)
- **04_BOUNDARIES** — Commander, Client, Adapter, SystemBus
- **05_LIFECYCLE** — Boot, venue start, WebSocket, advisor lifecycle
- **06_WORKERS** — Order worker pool, transition workers
- **07_INTEGRATION_PATTERNS** — Venue adapters, WebSocket, order book pipeline

## Key Patterns and Conventions

See `docs/guardrails/` for complete rules. Critical patterns:

1. **Decimal everywhere** — All monetary values use `Decimal`, never floats
2. **Order state machine** — All transitions go through `ApplyOrderTransition` + `OrderTransitionWorker`
3. **Venue adapter behavior** — All exchanges implement `Tai.Venues.Adapter`, accessed via `Tai.Venues.Client`
4. **TaiEvents for logging** — Never use `Logger` directly; use `TaiEvents.info/warning/error`
5. **ETS stores** — Runtime data in ETS via `Stored` library; orders in Ecto/database
6. **send_orders safety flag** — Must be enabled to actually submit orders to exchanges

## Known Issues

1. **Dialyzer warnings**: 10 active warnings (9 `callback_arg_type_mismatch` in Binance/Kraken/Gdax adapters, 1 `pattern_match_cov` in BitMEX). 46 suppressed entries in `.dialyzer_ignore.exs`.
2. **Venue adapter test failures**: 38 tests fail because they make real HTTP calls. These require actual API credentials to pass.
3. **Coverage gaps**: OrderTransitionWorker, OrderCallbackStore, Venues.Client, and some Commander delegates lack direct unit tests.

## Testing Approach

- **DataCase**: `Tai.TestSupport.DataCase` — restarts tai app, sets up SQL sandbox, starts mock server
- **Factories**: `create_order/1`, `build_submission/2`, `mock_product/1`
- **Mock adapter**: `Tai.VenueAdapters.Mock` with `Tai.TestSupport.Mocks.Server` for testing
- **Event testing**: `TaiEvents.firehose_subscribe()` then `assert_receive {TaiEvents.Event, %Event{}, :level}`
- **Process testing**: `:sys.get_state(pid)` for inspecting GenServer state

## Reference Implementations

When creating new code, reference these existing patterns:
- **New venue adapter**: Copy from `apps/tai/lib/tai/venue_adapters/stub.ex`
- **New order transition**: Follow `apps/tai/lib/tai/orders/transitions/accept_create.ex`
- **New event struct**: Follow `apps/tai/lib/tai/events/order_updated.ex`
- **New ETS store**: Follow `apps/tai/lib/tai/orders/order_callback_store.ex` (uses `Stored.Store`)
- **New test**: Follow `apps/tai/test/tai/orders/transitions/accept_create_test.exs`

## Director → Implementor Workflow

1. **Director** reads architecture docs, CLAUDE.md, guardrails
2. **Director** creates an ADR for architectural decisions in `docs/decisions/`
3. **Director** creates an implementation plan in `docs/plans/`
4. **Director** breaks work into module-level tasks
5. **Implementor** receives a task with specific module scope
6. **Implementor** reads referenced source files and existing tests
7. **Implementor** implements changes, runs `mix test`, adds `@spec` annotations
8. **Implementor** creates tests for new code
9. **Director** reviews against `docs/guardrails/CODE_REVIEW_CHECKLIST.md`
