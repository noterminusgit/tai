defmodule Tai.Events.BootAdvisorsTest do
  use ExUnit.Case, async: true

  test "struct has required fields" do
    event =
      struct!(Tai.Events.BootAdvisors,
        loaded_fleets: 3,
        loaded_advisors: 10,
        started_advisors: 8
      )

    assert event.loaded_fleets == 3
    assert event.loaded_advisors == 10
    assert event.started_advisors == 8
  end

  test ".to_data/1 returns the struct as a map" do
    event =
      struct!(Tai.Events.BootAdvisors,
        loaded_fleets: 3,
        loaded_advisors: 10,
        started_advisors: 8
      )

    assert %{} = json = TaiEvents.LogEvent.to_data(event)
    assert json.loaded_fleets == 3
    assert json.loaded_advisors == 10
    assert json.started_advisors == 8
  end
end
