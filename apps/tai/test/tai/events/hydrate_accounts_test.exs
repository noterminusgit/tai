defmodule Tai.Events.HydrateAccountsTest do
  use ExUnit.Case, async: true

  test "struct has required fields" do
    event =
      struct!(Tai.Events.HydrateAccounts,
        venue_id: :my_venue,
        total: 50,
        filtered: 10
      )

    assert event.venue_id == :my_venue
    assert event.total == 50
    assert event.filtered == 10
  end

  test ".to_data/1 returns the struct as a map" do
    event =
      struct!(Tai.Events.HydrateAccounts,
        venue_id: :my_venue,
        total: 50,
        filtered: 10
      )

    assert %{} = json = TaiEvents.LogEvent.to_data(event)
    assert json.venue_id == :my_venue
    assert json.total == 50
    assert json.filtered == 10
  end
end
