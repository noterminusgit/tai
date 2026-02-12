defmodule Tai.Events.ConnectedStatsTest do
  use ExUnit.Case, async: true

  test "struct has required fields" do
    {:ok, received_at, _} = DateTime.from_iso8601("2020-01-23T23:50:07.123+00:00")

    event =
      struct!(Tai.Events.ConnectedStats,
        venue_id: :my_venue,
        received_at: received_at,
        bots: 150,
        users: 1200
      )

    assert event.venue_id == :my_venue
    assert event.received_at == received_at
    assert event.bots == 150
    assert event.users == 1200
  end

  test ".to_data/1 returns the struct as a map" do
    {:ok, received_at, _} = DateTime.from_iso8601("2020-01-23T23:50:07.123+00:00")

    event =
      struct!(Tai.Events.ConnectedStats,
        venue_id: :my_venue,
        received_at: received_at,
        bots: 150,
        users: 1200
      )

    assert %{} = json = TaiEvents.LogEvent.to_data(event)
    assert json.venue_id == :my_venue
    assert json.bots == 150
    assert json.users == 1200
  end
end
