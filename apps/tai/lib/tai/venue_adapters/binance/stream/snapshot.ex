defmodule Tai.VenueAdapters.Binance.Stream.Snapshot do
  alias Tai.Markets.OrderBook

  @type product :: Tai.Venues.Product.t()
  @type change_set :: OrderBook.ChangeSet.t()

  @depth_url "https://api.binance.com/api/v3/depth"

  @spec fetch(product, pos_integer) :: {:ok, change_set}
  def fetch(product, depth) do
    with {:ok, %Req.Response{status: 200, body: venue_book}} <-
           Req.get("#{@depth_url}?symbol=#{product.venue_symbol}&limit=#{depth}") do
      received_at = System.monotonic_time()
      bids = venue_book["bids"] |> normalize_changes(:bid)
      asks = venue_book["asks"] |> normalize_changes(:ask)

      change_set = %OrderBook.ChangeSet{
        venue: product.venue_id,
        symbol: product.symbol,
        last_received_at: received_at,
        changes: Enum.concat(bids, asks)
      }

      {:ok, change_set}
    end
  end

  defp normalize_changes(venue_price_points, side) do
    venue_price_points
    |> Enum.map(fn [raw_price, raw_size] ->
      {price, _} = Float.parse(raw_price)
      {size, _} = Float.parse(raw_size)
      {:upsert, side, price, size}
    end)
  end
end
