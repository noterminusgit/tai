defmodule Tai.Events.UpdateLiquidationLeavesQtyTest do
  use ExUnit.Case, async: true

  test "struct has required fields" do
    {:ok, received_at, _} = DateTime.from_iso8601("2020-01-23T23:50:07.123+00:00")

    event =
      struct!(Tai.Events.UpdateLiquidationLeavesQty,
        venue_id: :my_venue,
        symbol: :btc_usd,
        received_at: received_at,
        leaves_qty: Decimal.new("0.75"),
        order_id: "liquidation-123"
      )

    assert event.venue_id == :my_venue
    assert event.symbol == :btc_usd
    assert event.received_at == received_at
    assert Decimal.eq?(event.leaves_qty, Decimal.new("0.75"))
    assert event.order_id == "liquidation-123"
  end

  test ".to_data/1 returns the struct as a map" do
    {:ok, received_at, _} = DateTime.from_iso8601("2020-01-23T23:50:07.123+00:00")

    event =
      struct!(Tai.Events.UpdateLiquidationLeavesQty,
        venue_id: :my_venue,
        symbol: :btc_usd,
        received_at: received_at,
        leaves_qty: Decimal.new("0.75"),
        order_id: "liquidation-123"
      )

    assert %{} = json = TaiEvents.LogEvent.to_data(event)
    assert json.venue_id == :my_venue
    assert json.symbol == :btc_usd
    assert json.order_id == "liquidation-123"
  end
end
