defmodule Tai.VenueAdapters.Kraken.Stream.Connection do
  use Tai.Venues.Streams.ConnectionAdapter
  alias Tai.VenueAdapters.Kraken.Stream

  @type stream :: Tai.Venues.Stream.t()
  @type endpoint :: String.t()
  @type credential_id :: Tai.Venue.credential_id()
  @type credential :: Tai.Venue.account()

  @spec start_link(
          endpoint: endpoint,
          stream: stream,
          credential: {credential_id, credential} | nil
        ) :: {:ok, pid}
  def start_link(endpoint: endpoint, stream: stream, credential: credential) do
    routes = %{
      order_books: stream.venue.id |> Stream.RouteOrderBooks.to_name(),
      optional_channels: stream.venue.id |> Stream.ProcessOptionalChannels.to_name()
    }

    state = %Tai.Venues.Streams.ConnectionAdapter.State{
      venue: stream.venue.id,
      routes: routes,
      channels: stream.venue.channels,
      credential: credential,
      markets: stream.markets,
      quote_depth: stream.venue.quote_depth,
      heartbeat_interval: stream.venue.stream_heartbeat_interval,
      heartbeat_timeout: stream.venue.stream_heartbeat_timeout,
      opts: stream.venue.opts,
      requests: %Tai.Venues.Streams.ConnectionAdapter.Requests{
        next_request_id: 1,
        pending_requests: %{}
      }
    }

    name = process_name(stream.venue.id)
    Fresh.start_link(endpoint, __MODULE__, state, name: {:local, name})
  end

  @impl true
  def subscribe(:init, state) do
    state.markets |> Enum.each(&send(self(), {:subscribe, {:order_book, &1}}))
    state.markets |> Enum.each(&send(self(), {:subscribe, {:trades, &1}}))
    {:ok, state}
  end

  @impl true
  def subscribe({:order_book, product}, state) do
    msg =
      %{
        event: "subscribe",
        pair: [product.venue_symbol],
        subscription: %{name: "book", depth: state.quote_depth || 10}
      }
      |> Jason.encode!()

    {:reply, {:text, msg}, state}
  end

  @impl true
  def subscribe({:trades, product}, state) do
    msg =
      %{
        event: "subscribe",
        pair: [product.venue_symbol],
        subscription: %{name: "trade"}
      }
      |> Jason.encode!()

    {:reply, {:text, msg}, state}
  end

  @impl true
  def on_msg(%{"event" => "systemStatus"}, _received_at, state), do: {:ok, state}

  @impl true
  def on_msg(%{"event" => "subscriptionStatus", "status" => "subscribed"}, _received_at, state) do
    {:ok, state}
  end

  @impl true
  def on_msg(%{"event" => "heartbeat"}, _received_at, state), do: {:ok, state}

  @impl true
  def on_msg(data, received_at, state) when is_list(data) do
    handle_channel_data(data, received_at, state)
    {:ok, state}
  end

  @impl true
  def on_msg(_msg, _received_at, state), do: {:ok, state}

  defp handle_channel_data([_channel_id, data, channel_name, venue_symbol], received_at, state)
       when is_map(data) do
    cond do
      String.contains?(channel_name, "book") ->
        route_order_book(data, venue_symbol, received_at, state)

      String.contains?(channel_name, "trade") ->
        forward_trades(data, venue_symbol, received_at, state)

      true ->
        :ok
    end
  end

  defp handle_channel_data([_channel_id, data, channel_name | rest], received_at, state)
       when is_map(data) do
    venue_symbol = List.last(rest)

    cond do
      String.contains?(channel_name, "book") ->
        route_order_book(data, venue_symbol, received_at, state)

      String.contains?(channel_name, "trade") ->
        forward_trades(data, venue_symbol, received_at, state)

      true ->
        :ok
    end
  end

  defp handle_channel_data(_data, _received_at, _state), do: :ok

  defp route_order_book(data, venue_symbol, received_at, state) do
    msg_type = if Map.has_key?(data, "as") || Map.has_key?(data, "bs"), do: :snapshot, else: :update

    state.routes
    |> Map.fetch!(:order_books)
    |> GenServer.cast({msg_type, venue_symbol, data, received_at})
  end

  defp forward_trades(data, venue_symbol, received_at, state) do
    state.routes
    |> Map.fetch!(:optional_channels)
    |> GenServer.cast({:trade, venue_symbol, data, received_at})
  end
end
