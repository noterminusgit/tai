defmodule Tai.Events.SettlementTest do
  use ExUnit.Case, async: true

  test "struct has required fields" do
    {:ok, received_at, _} = DateTime.from_iso8601("2020-01-23T23:50:07.123+00:00")
    {:ok, timestamp, _} = DateTime.from_iso8601("2020-01-24T00:00:00.000+00:00")

    event =
      struct!(Tai.Events.Settlement,
        venue_id: :my_venue,
        symbol: :btc_usd,
        timestamp: timestamp,
        received_at: received_at,
        price: Decimal.new("50000.50")
      )

    assert event.venue_id == :my_venue
    assert event.symbol == :btc_usd
    assert event.timestamp == timestamp
    assert event.received_at == received_at
    assert Decimal.eq?(event.price, Decimal.new("50000.50"))
  end

  test ".to_data/1 returns the struct as a map" do
    {:ok, received_at, _} = DateTime.from_iso8601("2020-01-23T23:50:07.123+00:00")
    {:ok, timestamp, _} = DateTime.from_iso8601("2020-01-24T00:00:00.000+00:00")

    event =
      struct!(Tai.Events.Settlement,
        venue_id: :my_venue,
        symbol: :btc_usd,
        timestamp: timestamp,
        received_at: received_at,
        price: Decimal.new("50000.50")
      )

    assert %{} = json = TaiEvents.LogEvent.to_data(event)
    assert json.venue_id == :my_venue
    assert json.symbol == :btc_usd
  end
end
