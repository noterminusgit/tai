defmodule Tai.VenueAdapters.Kraken.Stream.ProcessOrderBook do
  use GenServer
  alias Tai.Markets.OrderBook

  defmodule State do
    @type venue :: Tai.Venue.id()
    @type product_symbol :: Tai.Venues.Product.symbol()
    @type t :: %State{venue: venue, symbol: product_symbol}

    @enforce_keys ~w(venue symbol)a
    defstruct ~w(venue symbol)a
  end

  @type venue :: Tai.Venue.id()
  @type venue_symbol :: Tai.Venues.Product.venue_symbol()
  @type product :: Tai.Venues.Product.t()
  @type state :: State.t()

  @spec start_link(product) :: GenServer.on_start()
  def start_link(product) do
    state = %State{venue: product.venue_id, symbol: product.symbol}
    name = to_name(product.venue_id, product.venue_symbol)
    GenServer.start_link(__MODULE__, state, name: name)
  end

  @spec to_name(venue, venue_symbol) :: atom
  def to_name(venue, venue_symbol), do: :"#{__MODULE__}_#{venue}_#{venue_symbol}"

  @spec init(state) :: {:ok, state}
  def init(state) do
    {:ok, state}
  end

  def handle_cast({:snapshot, data, received_at}, state) do
    {data, received_at, state}
    |> build_change_set()
    |> OrderBook.replace()

    {:noreply, state}
  end

  def handle_cast({:update, data, received_at}, state) do
    {data, received_at, state}
    |> build_change_set()
    |> OrderBook.apply()

    {:noreply, state}
  end

  def handle_cast(msg, state) do
    TaiEvents.warning(%Tai.Events.StreamMessageUnhandled{
      venue_id: state.venue,
      msg: msg,
      received_at: System.monotonic_time()
    })

    {:noreply, state}
  end

  defp build_change_set({data, received_at, state}) do
    normalized_bids = data |> normalize_changes(:bid)
    normalized_asks = data |> normalize_changes(:ask)

    %OrderBook.ChangeSet{
      venue: state.venue,
      symbol: state.symbol,
      last_venue_timestamp: nil,
      last_received_at: received_at,
      changes: Enum.concat(normalized_bids, normalized_asks)
    }
  end

  defp normalize_changes(data, :bid) do
    data
    |> Map.get("bs", Map.get(data, "b", []))
    |> normalize_side(:bid)
  end

  defp normalize_changes(data, :ask) do
    data
    |> Map.get("as", Map.get(data, "a", []))
    |> normalize_side(:ask)
  end

  defp normalize_side(data, side) when is_list(data) do
    data
    |> Enum.map(fn
      [price, "0.00000000" | _] -> {:delete, side, parse_price(price)}
      [price, volume | _] -> {:upsert, side, parse_price(price), parse_price(volume)}
    end)
  end

  defp normalize_side(_, _side), do: []

  defp parse_price(value) when is_binary(value) do
    case Decimal.parse(value) do
      {decimal, _} -> decimal
      :error -> Decimal.new(0)
    end
  end

  defp parse_price(value) when is_number(value), do: Decimal.new(value)
end
