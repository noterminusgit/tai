defmodule Tai.Events.VenueStopTest do
  use ExUnit.Case, async: true

  test "struct has required fields" do
    event = %Tai.Events.VenueStop{venue: :my_venue}

    assert event.venue == :my_venue
  end

  test ".to_data/1 returns the struct as a map" do
    event = %Tai.Events.VenueStop{venue: :my_venue}

    assert %{} = json = TaiEvents.LogEvent.to_data(event)
    assert json.venue == :my_venue
  end
end
