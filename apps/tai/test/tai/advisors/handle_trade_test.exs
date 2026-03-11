defmodule Tai.Advisors.HandleTradeTest do
  use Tai.TestSupport.DataCase, async: false
  alias Tai.Markets.Trade

  defmodule MyAdvisor do
    use Tai.Advisor

    def handle_trade(trade, state) do
      if Map.has_key?(state.config, :error) do
        raise state.config.error
      end

      counter = state.store |> Map.get(:event_counter, 0)
      new_store = state.store |> Map.put(:event_counter, counter + 1)
      send(:test, {:handle_trade_called, trade})

      if Map.has_key?(state.config, :return_val) do
        state.config[:return_val]
      else
        {:ok, new_store}
      end
    end
  end

  @venue :my_venue
  @symbol :btc_usd
  @fleet_id :fleet_a
  @advisor_id :my_advisor
  @advisor_process Tai.Advisor.process_name(@fleet_id, @advisor_id)
  @trade %Trade{
    id: "trade-1",
    venue: @venue,
    product_symbol: @symbol,
    price: Decimal.new("101.2"),
    qty: Decimal.new("1.0"),
    side: "buy",
    liquidation: false,
    received_at: System.monotonic_time(),
    venue_timestamp: nil
  }

  defp start_advisor!(advisor, config \\ %{}) do
    start_supervised!({
      advisor,
      [
        advisor_id: @advisor_id,
        fleet_id: @fleet_id,
        market_stream_keys: [{@venue, @symbol}],
        config: config,
        store: %{event_counter: 0}
      ]
    })
  end

  setup do
    Process.register(self(), :test)
    mock_product(%{venue_id: @venue, symbol: @symbol})

    :ok
  end

  test "fires the handle_trade callback" do
    start_advisor!(MyAdvisor)

    send(@advisor_process, @trade)

    assert_receive {:handle_trade_called, received_trade}

    assert received_trade.venue == @venue
    assert received_trade.product_symbol == @symbol
    assert received_trade.price == Decimal.new("101.2")
    assert received_trade.qty == Decimal.new("1.0")
    assert received_trade.side == "buy"
  end

  test "stores trade in state.trades (not market_quotes)" do
    start_advisor!(MyAdvisor)

    send(@advisor_process, @trade)
    assert_receive {:handle_trade_called, _}

    state = :sys.get_state(@advisor_process)
    assert state.trades.data[{@venue, @symbol}] == @trade
    assert state.market_quotes.data == %{}
  end

  test "emits an event and maintains state between callbacks when return is invalid" do
    TaiEvents.firehose_subscribe()
    start_advisor!(MyAdvisor, %{return_val: {:unknown, :return_val}})

    send(@advisor_process, @trade)

    assert_receive {
      TaiEvents.Event,
      %Tai.Events.AdvisorHandleTradeInvalidReturn{} = event,
      :warning
    }

    assert event.advisor_id == :my_advisor
    assert event.fleet_id == :fleet_a
    assert event.event == @trade
    assert event.return_value == {:unknown, :return_val}

    send(@advisor_process, @trade)

    assert_receive {TaiEvents.Event, %Tai.Events.AdvisorHandleTradeInvalidReturn{} = event_2, _}
    assert event_2.return_value == {:unknown, :return_val}
  end

  test "emits an event and maintains state between callbacks when an error is raised" do
    TaiEvents.firehose_subscribe()
    start_advisor!(MyAdvisor, %{error: "!!!This is an ERROR!!!"})

    send(@advisor_process, @trade)

    assert_receive {
      TaiEvents.Event,
      %Tai.Events.AdvisorHandleTradeError{} = event_1,
      :warning
    }

    assert event_1.advisor_id == :my_advisor
    assert event_1.fleet_id == :fleet_a
    assert event_1.event == @trade
    assert event_1.error == %RuntimeError{message: "!!!This is an ERROR!!!"}
    assert [stack_1 | _] = event_1.stacktrace
    assert {Tai.Advisors.HandleTradeTest.MyAdvisor, :handle_trade, 2, stack_1_location} = stack_1
    assert Keyword.fetch!(stack_1_location, :file) != nil
    assert Keyword.fetch!(stack_1_location, :line) != nil

    send(@advisor_process, @trade)

    assert_receive {
      TaiEvents.Event,
      %Tai.Events.AdvisorHandleTradeError{} = event_2,
      :warning
    }

    assert event_2.error == %RuntimeError{message: "!!!This is an ERROR!!!"}
  end
end
