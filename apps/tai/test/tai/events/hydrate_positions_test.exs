defmodule Tai.Events.HydratePositionsTest do
  use ExUnit.Case, async: true

  test "struct has required fields" do
    event =
      struct!(Tai.Events.HydratePositions,
        venue_id: :my_venue,
        total: 5
      )

    assert event.venue_id == :my_venue
    assert event.total == 5
  end

  test ".to_data/1 returns the struct as a map" do
    event =
      struct!(Tai.Events.HydratePositions,
        venue_id: :my_venue,
        total: 5
      )

    assert %{} = json = TaiEvents.LogEvent.to_data(event)
    assert json.venue_id == :my_venue
    assert json.total == 5
  end
end
