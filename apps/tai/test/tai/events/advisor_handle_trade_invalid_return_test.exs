defmodule Tai.Events.AdvisorHandleTradeInvalidReturnTest do
  use ExUnit.Case, async: true

  test ".to_data/1 transforms event & return_value to a string" do
    event =
      struct!(Tai.Events.AdvisorHandleTradeInvalidReturn,
        advisor_id: :my_advisor,
        fleet_id: :my_fleet,
        event: {:some, :trade_event},
        return_value: {:invalid, :return}
      )

    assert %{} = json = TaiEvents.LogEvent.to_data(event)
    assert json.advisor_id == :my_advisor
    assert json.fleet_id == :my_fleet
    assert json.event == "{:some, :trade_event}"
    assert json.return_value == "{:invalid, :return}"
  end
end
