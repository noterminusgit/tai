defmodule Tai.VenueAdapters.Kraken.Stream.ProcessOptionalChannels do
  use GenServer

  defmodule State do
    @type venue_id :: Tai.Venue.id()
    @type t :: %State{venue: venue_id}

    @enforce_keys ~w(venue)a
    defstruct ~w(venue)a
  end

  @type venue_id :: Tai.Venue.id()
  @type state :: State.t()

  @spec start_link(venue: venue_id) :: GenServer.on_start()
  def start_link(venue: venue) do
    state = %State{venue: venue}
    name = to_name(venue)
    GenServer.start_link(__MODULE__, state, name: name)
  end

  @spec to_name(venue_id) :: atom
  def to_name(venue), do: :"#{__MODULE__}_#{venue}"

  @spec init(state) :: {:ok, state}
  def init(state) do
    {:ok, state}
  end

  def handle_cast({:trade, _venue_symbol, trades, _received_at}, state) do
    process_trades(trades, state)
    {:noreply, state}
  end

  def handle_cast(_msg, state) do
    {:noreply, state}
  end

  defp process_trades(trades, _state) when is_list(trades) do
    # Process trade data
    # In a production implementation, this would broadcast trade events
    :ok
  end

  defp process_trades(_trades, _state), do: :ok
end
