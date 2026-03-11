# ALWAYS DO

Required practices for all contributions to the Tai trading toolkit. These patterns maintain consistency, correctness, and reliability across the codebase.

## 1. Use Decimal for all monetary and quantity values

Every price, quantity, balance, fee, and notional value must be represented as a `Decimal`. This applies to struct fields, function parameters, return values, and test assertions.

```elixir
defstruct [
  price: Decimal.new(0),
  qty: Decimal.new(0),
  cumulative_qty: Decimal.new(0)
]
```

## 2. Define `@type t` and `@enforce_keys` on structs

All structs must declare a `@type t :: %__MODULE__{}` typespec and use `@enforce_keys` to list required fields. This enables Dialyzer checking and ensures structs are not constructed with missing data.

```elixir
defmodule Tai.Orders.Responses.CreateAccepted do
  @enforce_keys ~w[id venue_order_id]a
  defstruct ~w[id venue_order_id]a

  @type t :: %__MODULE__{
    id: String.t(),
    venue_order_id: String.t()
  }
end
```

## 3. Implement all `Tai.Venues.Adapter` callbacks

Venue adapters must implement every callback defined by the `Tai.Venues.Adapter` behavior. For operations the exchange does not support, return `{:error, :not_supported}` or `{:error, :not_implemented}`. Never leave callbacks undefined.

## 4. Use TaiEvents for structured logging

All log output must go through `TaiEvents`, emitting typed event structs. Each event struct should live under `Tai.Events.*` and implement the required protocol for rendering.

```elixir
TaiEvents.warning(%Tai.Events.VenueConnectionError{
  venue_id: venue.id,
  reason: reason
})
```

## 5. Implement `Tai.Orders.Transition` behavior for new state transitions

When adding a new order state transition, create a module under `Tai.Orders.Transitions.*` that implements the `Tai.Orders.Transition` behavior. The behavior enforces a consistent interface for validating and applying state changes.

## 6. Use PolymorphicEmbed for order transition storage

Order transitions are stored using `PolymorphicEmbed` to support different data shapes per transition type. When adding a new transition, register it in the polymorphic embed configuration so it can be serialized and deserialized correctly.

## 7. Add `@spec` to all public functions

Every public function must have an `@spec` annotation. This supports Dialyzer analysis and serves as inline documentation for callers.

```elixir
@spec cancel_order(Tai.Orders.Order.t()) ::
        {:ok, Tai.Orders.Order.t()} | {:error, term()}
def cancel_order(order) do
  ...
end
```

## 8. Run `mix test` before and after changes

Always run the full test suite before starting work (to confirm a clean baseline) and after completing changes (to confirm nothing is broken). Use `mix test` for the full suite or target specific files during development.

```bash
# Full suite
mix test

# Targeted
mix test apps/tai/test/tai/orders_test.exs
```

## 9. Follow existing patterns

New code should mirror the structure and conventions of existing modules. Transition modules follow the pattern established by `AcceptCreate`. Venue adapters follow the stub adapter structure. Advisors follow the examples in `apps/examples`. When in doubt, find the closest existing module and use it as a template.

## 10. Use factories and mocks from `Tai.TestSupport` in tests

Tests must use the factory functions and mock utilities provided by `Tai.TestSupport`. This includes `DataCase` for database-backed tests, `Mock` for venue adapter mocking, and factory helpers for building test data. Never construct test fixtures by hand when a factory exists.

```elixir
defmodule Tai.MyFeatureTest do
  use Tai.TestSupport.DataCase, async: false

  test "example" do
    product = build(:product, venue_id: :test_exchange)
    ...
  end
end
```
