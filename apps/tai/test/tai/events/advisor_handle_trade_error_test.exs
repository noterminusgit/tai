defmodule Tai.Events.AdvisorHandleTradeErrorTest do
  use ExUnit.Case, async: true

  test ".to_data/1 transforms event, error, and stacktrace to strings" do
    event =
      struct!(Tai.Events.AdvisorHandleTradeError,
        advisor_id: :my_advisor,
        fleet_id: :my_fleet,
        event: {:some, :trade_event},
        error: %RuntimeError{message: "trade error"},
        stacktrace: [{MyModule, :handle_trade, 2, [file: "my_module.ex", line: 100]}]
      )

    assert %{} = json = TaiEvents.LogEvent.to_data(event)
    assert json.advisor_id == :my_advisor
    assert json.fleet_id == :my_fleet
    assert json.event == "{:some, :trade_event}"
    assert json.error == "%RuntimeError{message: \"trade error\"}"
    assert json.stacktrace == "[{MyModule, :handle_trade, 2, [file: \"my_module.ex\", line: 100]}]"
  end
end
