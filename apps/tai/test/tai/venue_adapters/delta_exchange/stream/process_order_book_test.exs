defmodule Tai.VenueAdapters.DeltaExchange.Stream.ProcessOrderBookTest do
  use Tai.TestSupport.DataCase, async: false
  alias Tai.VenueAdapters.DeltaExchange.Stream.ProcessOrderBook
  alias Tai.Markets.{OrderBook, PricePoint, Quote}

  defp decimal(val), do: Decimal.new(val)

  @product struct(Tai.Venues.Product,
             venue_id: :venue_a,
             symbol: :btcusd,
             venue_symbol: "BTCUSD"
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

  test "can snapshot the order book", %{pid: pid} do
    bids = [%{"limit_price" => "100.5", "size" => 5}]
    asks = [%{"limit_price" => "101.5", "size" => 10}]

    GenServer.cast(pid, {:snapshot, {bids, asks}, System.monotonic_time()})

    assert_receive %Quote{} = market_quote
    assert Enum.count(market_quote.bids) == 1
    assert Enum.at(market_quote.bids, 0) == %PricePoint{price: decimal("100.5"), size: decimal("5")}
    assert Enum.count(market_quote.asks) == 1
    assert Enum.at(market_quote.asks, 0) == %PricePoint{price: decimal("101.5"), size: decimal("10")}
  end

  test "returns Decimal types in price points", %{pid: pid} do
    bids = [%{"limit_price" => "100.50", "size" => 5}]
    asks = [%{"limit_price" => "101.75", "size" => 10}]

    GenServer.cast(pid, {:snapshot, {bids, asks}, System.monotonic_time()})

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
