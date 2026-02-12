defmodule Tai.Events.HydrateProductsTest do
  use ExUnit.Case, async: true

  test "struct has required fields" do
    event =
      struct!(Tai.Events.HydrateProducts,
        venue_id: :my_venue,
        total: 100,
        filtered: 25
      )

    assert event.venue_id == :my_venue
    assert event.total == 100
    assert event.filtered == 25
  end

  test ".to_data/1 returns the struct as a map" do
    event =
      struct!(Tai.Events.HydrateProducts,
        venue_id: :my_venue,
        total: 100,
        filtered: 25
      )

    assert %{} = json = TaiEvents.LogEvent.to_data(event)
    assert json.venue_id == :my_venue
    assert json.total == 100
    assert json.filtered == 25
  end
end
