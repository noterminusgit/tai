defmodule Tai.Events.AdvisorHandleMarketQuoteErrorTest do
  use ExUnit.Case, async: true

  test ".to_data/1 transforms event, error, and stacktrace to strings" do
    event =
      struct!(Tai.Events.AdvisorHandleMarketQuoteError,
        advisor_id: :my_advisor,
        fleet_id: :my_fleet,
        event: {:some, :market_quote_event},
        error: %RuntimeError{message: "test error"},
        stacktrace: [{MyModule, :my_func, 1, [file: "my_module.ex", line: 42]}]
      )

    assert %{} = json = TaiEvents.LogEvent.to_data(event)
    assert json.advisor_id == :my_advisor
    assert json.fleet_id == :my_fleet
    assert json.event == "{:some, :market_quote_event}"
    assert json.error == "%RuntimeError{message: \"test error\"}"
    assert json.stacktrace == "[{MyModule, :my_func, 1, [file: \"my_module.ex\", line: 42]}]"
  end
end
