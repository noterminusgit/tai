# Code Review Checklist

Use this checklist when reviewing any change to the Tai trading toolkit. Every item must pass before a change is approved.

## Monetary Values

- [ ] All prices, quantities, balances, and fees use `Decimal` (no floats, no integers for monetary amounts)
- [ ] Arithmetic on monetary values uses `Decimal.add/2`, `Decimal.mult/2`, `Decimal.compare/2`, etc.
- [ ] No implicit float conversion occurs (e.g., via `String.to_float/1` or `elem/2` on external API responses without conversion)

## Order Lifecycle

- [ ] Order creation goes through `Tai.Orders.Services.EnqueueOrder`
- [ ] Order state changes go through the transition state machine (`Tai.Orders.Transitions.*`)
- [ ] State transitions are processed via `OrderTransitionWorker` (no direct updates)
- [ ] New transitions implement the `Tai.Orders.Transition` behavior
- [ ] New transitions are registered in the `PolymorphicEmbed` configuration
- [ ] The `send_orders` safety flag is respected (not bypassed or ignored)

## Venue Adapters

- [ ] Adapter implements all `Tai.Venues.Adapter` callbacks
- [ ] Unsupported operations return `{:error, :not_supported}` or `{:error, :not_implemented}`
- [ ] External calls go through `Tai.Venues.Client`, not directly to adapter modules
- [ ] Credentials are read from `confex` configuration (no hardcoded keys)

## Structs and Types

- [ ] All structs define `@type t :: %__MODULE__{}`
- [ ] All structs use `@enforce_keys` for required fields
- [ ] All public functions have `@spec` annotations

## Logging and Events

- [ ] All logging uses `TaiEvents` with typed event structs
- [ ] No direct calls to `Logger.info/1`, `Logger.warn/1`, `Logger.error/1`, etc.
- [ ] New event structs are placed under `Tai.Events.*`

## Data Stores

- [ ] ETS stores are accessed through their public API modules (not raw `:ets` calls)
- [ ] SystemBus publishing uses appropriate, non-reserved topics for custom events

## Tests

- [ ] New functionality has corresponding tests
- [ ] Tests use `Tai.TestSupport.DataCase` where database access is needed
- [ ] Tests use factories and mocks from `Tai.TestSupport`
- [ ] Both success and error paths are tested
- [ ] `mix test` passes with no failures
- [ ] `mix format` produces no changes (code is already formatted)

## General

- [ ] New code follows the patterns of the closest existing module
- [ ] No new dependencies added without explicit justification
- [ ] No files modified outside the stated scope of the change
- [ ] Commit message clearly describes the change
