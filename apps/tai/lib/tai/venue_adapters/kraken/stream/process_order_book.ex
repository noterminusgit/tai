defmodule Tai.VenueAdapters.Kraken.Stream.ProcessOrderBook do
  use GenServer
  alias Tai.Markets.OrderBook

  defmodule State do
    @type t :: %State{venue: atom}
    defstruct ~w[venue]a
  end

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(args) do
    venue = Keyword.fetch!(args, :venue)
    {:ok, %State{venue: venue}}
  end

  def handle_msg(msg, connection_state) do
    GenServer.cast(__MODULE__, {:handle_msg, msg, connection_state})
    {:noreply, connection_state}
  end

  def handle_cast({:handle_msg, msg, _connection_state}, state) do
    process_msg(msg, state)
    {:noreply, state}
  end

  defp process_msg(%{"as" => asks, "bs" => bids} = data, state) do
    # Snapshot message
    product = extract_product(data, state.venue)

    if product do
      changes = %{
        bids: parse_price_points(bids),
        asks: parse_price_points(asks)
      }

      :ok = OrderBook.replace(product, changes)
    end
  end

  defp process_msg(%{"a" => asks, "b" => bids} = data, state) do
    # Update message
    product = extract_product(data, state.venue)

    if product do
      changes = %{
        bids: parse_price_points(bids),
        asks: parse_price_points(asks)
      }

      :ok = OrderBook.apply(product, changes)
    end
  end

  defp process_msg(_msg, _state), do: :ok

  defp extract_product(_data, venue) do
    # In a real implementation, we'd need to map the channel ID back to the product
    # For now, this is a placeholder
    %Tai.Markets.Product{venue_id: venue, symbol: :xbtusd}
  end

  defp parse_price_points(points) when is_list(points) do
    points
    |> Enum.map(fn [price, volume, _timestamp] ->
      {parse_decimal(price), parse_decimal(volume)}
    end)
  end

  defp parse_price_points(_), do: []

  defp parse_decimal(value) when is_binary(value) do
    case Decimal.parse(value) do
      {decimal, _} -> decimal
      :error -> Decimal.new(0)
    end
  end

  defp parse_decimal(value) when is_number(value), do: Decimal.new(value)
end
