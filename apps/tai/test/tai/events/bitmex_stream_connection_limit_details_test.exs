defmodule Tai.Events.BitmexStreamConnectionLimitDetailsTest do
  use ExUnit.Case, async: true

  test "struct has required fields" do
    event =
      struct!(Tai.Events.BitmexStreamConnectionLimitDetails,
        venue_id: :bitmex,
        remaining: 15
      )

    assert event.venue_id == :bitmex
    assert event.remaining == 15
  end

  test ".to_data/1 returns the struct as a map" do
    event =
      struct!(Tai.Events.BitmexStreamConnectionLimitDetails,
        venue_id: :bitmex,
        remaining: 15
      )

    assert %{} = json = TaiEvents.LogEvent.to_data(event)
    assert json.venue_id == :bitmex
    assert json.remaining == 15
  end
end
