defmodule Tai.VenueAdapters.Binance.Stream.ProcessOrderBookTest do
  use Tai.TestSupport.DataCase, async: false
  alias Tai.VenueAdapters.Binance.Stream.ProcessOrderBook
  alias Tai.Markets.{OrderBook, PricePoint, Quote}

  defp decimal(val), do: Decimal.new(val)

  @product struct(Tai.Venues.Product,
             venue_id: :venue_a,
             symbol: :xbtusd,
             venue_symbol: "XBTUSD"
           )
  @order_book_name OrderBook.to_name(@product.venue_id, @product.venue_symbol)
  @quote_depth 1

  setup do
    Process.register(self(), @order_book_name)
    start_supervised!(OrderBook.child_spec(@product, @quote_depth, false))
    {:ok, pid} = start_supervised({ProcessOrderBook, @product})
    Tai.Markets.subscribe_quote(@product.venue_id)

    {:ok, %{pid: pid}}
  end

  test "can insert new price points into the order book", %{pid: pid} do
    data = %{
      "E" => 1_569_054_255_636,
      "s" => @product.venue_symbol,
      "b" => [["100", "15"]],
      "a" => [["101", "11"]]
    }

    GenServer.cast(pid, {:update, data, Timex.now()})

    assert_receive %Quote{} = market_quote
    assert Enum.count(market_quote.bids) == 1
    assert Enum.at(market_quote.bids, 0) == %PricePoint{price: decimal("100"), size: decimal("15")}
    assert Enum.count(market_quote.asks) == 1
    assert Enum.at(market_quote.asks, 0) == %PricePoint{price: decimal("101"), size: decimal("11")}
    assert %DateTime{} = market_quote.last_venue_timestamp
    assert market_quote.last_received_at != nil
  end

  test "can update existing price points in the order book", %{pid: pid} do
    snapshot =
      struct(OrderBook.ChangeSet,
        venue: @product.venue_id,
        symbol: @product.symbol,
        changes: [
          {:upsert, :bid, decimal("100"), decimal("5")},
          {:upsert, :ask, decimal("101"), decimal("10")}
        ]
      )

    OrderBook.replace(snapshot)

    assert_receive %Quote{} = _

    data = %{
      "E" => 1_569_054_255_636,
      "s" => @product.venue_symbol,
      "b" => [["100", "15"]],
      "a" => [["101", "11"]]
    }

    GenServer.cast(pid, {:update, data, Timex.now()})

    assert_receive %Quote{} = market_quote
    assert Enum.count(market_quote.bids) == 1
    assert Enum.at(market_quote.bids, 0) == %PricePoint{price: decimal("100"), size: decimal("15")}
    assert Enum.count(market_quote.asks) == 1
    assert Enum.at(market_quote.asks, 0) == %PricePoint{price: decimal("101"), size: decimal("11")}
    assert %DateTime{} = market_quote.last_venue_timestamp
    assert market_quote.last_received_at != nil
  end

  test "can delete existing price points from the order book", %{pid: pid} do
    snapshot =
      struct(OrderBook.ChangeSet,
        venue: @product.venue_id,
        symbol: @product.symbol,
        changes: [
          {:upsert, :bid, decimal("100"), decimal("5")},
          {:upsert, :ask, decimal("101"), decimal("10")}
        ]
      )

    OrderBook.replace(snapshot)

    assert_receive %Quote{} = _

    data = %{
      "E" => 1_569_054_255_636,
      "s" => @product.venue_symbol,
      "b" => [["100", "0"]],
      "a" => [["101", "0"]]
    }

    GenServer.cast(pid, {:update, data, Timex.now()})

    assert_receive %Quote{} = market_quote
    assert Enum.empty?(market_quote.bids)
    assert Enum.empty?(market_quote.asks)
    assert %DateTime{} = market_quote.last_venue_timestamp
    assert market_quote.last_received_at != nil
  end

  test "returns Decimal types in price points", %{pid: pid} do
    data = %{
      "E" => 1_569_054_255_636,
      "s" => @product.venue_symbol,
      "b" => [["100.50", "15.25"]],
      "a" => [["101.75", "11.50"]]
    }

    GenServer.cast(pid, {:update, data, Timex.now()})

    assert_receive %Quote{} = market_quote
    bid = Enum.at(market_quote.bids, 0)
    ask = Enum.at(market_quote.asks, 0)
    assert %Decimal{} = bid.price
    assert %Decimal{} = bid.size
    assert %Decimal{} = ask.price
    assert %Decimal{} = ask.size
  end

  test "handles unexpected messages without crashing", %{pid: pid} do
    GenServer.cast(pid, {:unexpected, %{}, System.monotonic_time()})
    assert Process.alive?(pid)
  end
end
