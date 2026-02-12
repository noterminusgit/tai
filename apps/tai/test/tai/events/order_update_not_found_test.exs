defmodule Tai.Events.OrderUpdateNotFoundTest do
  use ExUnit.Case, async: true

  test "struct has required fields" do
    event =
      struct!(Tai.Events.OrderUpdateNotFound,
        client_id: "order-123",
        transition: Tai.Orders.Transitions.Open
      )

    assert event.client_id == "order-123"
    assert event.transition == Tai.Orders.Transitions.Open
  end

  test ".to_data/1 returns the struct as a map" do
    event =
      struct!(Tai.Events.OrderUpdateNotFound,
        client_id: "order-123",
        transition: Tai.Orders.Transitions.Open
      )

    assert %{} = json = TaiEvents.LogEvent.to_data(event)
    assert json.client_id == "order-123"
    assert json.transition == Tai.Orders.Transitions.Open
  end
end
