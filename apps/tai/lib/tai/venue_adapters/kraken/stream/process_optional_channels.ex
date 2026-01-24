defmodule Tai.VenueAdapters.Kraken.Stream.ProcessOptionalChannels do
  use GenServer

  defmodule State do
    @type t :: %State{venue: atom, products: list}
    defstruct ~w[venue products]a
  end

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(args) do
    venue = Keyword.fetch!(args, :venue)
    products = Keyword.fetch!(args, :products)
    {:ok, %State{venue: venue, products: products}}
  end

  def handle_msg(msg, connection_state) do
    GenServer.cast(__MODULE__, {:handle_msg, msg, connection_state})
    {:noreply, connection_state}
  end

  def handle_cast({:handle_msg, {:trade, trades}, _connection_state}, state) do
    process_trades(trades, state)
    {:noreply, state}
  end

  def handle_cast({:handle_msg, _msg, _connection_state}, state) do
    {:noreply, state}
  end

  defp process_trades(trades, state) when is_list(trades) do
    # Process trade data
    # In a production implementation, this would broadcast trade events
    :ok
  end

  defp process_trades(_trades, _state), do: :ok
end
