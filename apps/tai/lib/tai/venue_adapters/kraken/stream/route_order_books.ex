defmodule Tai.VenueAdapters.Kraken.Stream.RouteOrderBooks do
  use GenServer
  alias Tai.VenueAdapters.Kraken.Stream

  defmodule State do
    @type venue_id :: Tai.Venue.id()
    @type venue_symbol :: Tai.Venues.Product.venue_symbol()
    @type store_name :: atom
    @type stores :: %{optional(venue_symbol) => store_name}
    @type t :: %State{venue: venue_id, stores: stores}

    @enforce_keys ~w(venue stores)a
    defstruct ~w(venue stores)a
  end

  @type venue_id :: Tai.Venue.id()
  @type product :: Tai.Venues.Product.t()
  @type state :: State.t()

  @spec start_link(venue: venue_id, order_books: [product]) :: GenServer.on_start()
  def start_link(venue: venue, order_books: order_books) do
    stores = order_books |> build_stores()
    state = %State{venue: venue, stores: stores}
    name = venue |> to_name()
    GenServer.start_link(__MODULE__, state, name: name)
  end

  @spec to_name(venue_id) :: atom
  def to_name(venue), do: :"#{__MODULE__}_#{venue}"

  @spec init(state) :: {:ok, state}
  def init(state) do
    {:ok, state}
  end

  # Handle snapshot messages (contains "as" and "bs" keys)
  def handle_cast({:snapshot, venue_symbol, data, received_at}, state) do
    {state, venue_symbol}
    |> forward({:snapshot, data, received_at})

    {:noreply, state}
  end

  # Handle update messages (contains "a" and "b" keys)
  def handle_cast({:update, venue_symbol, data, received_at}, state) do
    {state, venue_symbol}
    |> forward({:update, data, received_at})

    {:noreply, state}
  end

  defp build_stores(order_books) do
    order_books
    |> Enum.reduce(
      %{},
      fn p, acc ->
        name = Stream.ProcessOrderBook.to_name(p.venue_id, p.venue_symbol)
        Map.put(acc, p.venue_symbol, name)
      end
    )
  end

  defp forward({state, venue_symbol}, msg) do
    case Map.fetch(state.stores, venue_symbol) do
      {:ok, store_name} -> GenServer.cast(store_name, msg)
      :error -> :ok
    end
  end
end
