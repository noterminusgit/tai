defmodule Tai.VenueAdapters.Mock.Stream.Connection do
  @behaviour Fresh
  alias Tai.Markets.OrderBook
  alias Tai.Orders

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      restart: :transient
    }
  end

  defmodule State do
    @type venue_id :: Tai.Venue.id()
    @type t :: %State{venue: venue_id}

    @enforce_keys ~w[venue]a
    defstruct ~w[venue]a
  end

  @type stream :: Tai.Venues.Stream.t()
  @type venue_id :: Tai.Venue.id()
  @type credential_id :: Tai.Venue.credential_id()
  @type credential :: Tai.Venue.credential()
  @type msg :: map

  @spec start_link(
          endpoint: String.t(),
          stream: stream,
          credential: {credential_id, credential} | nil
        ) :: {:ok, pid}
  def start_link(endpoint: endpoint, stream: stream, credential: _) do
    state = %State{venue: stream.venue.id}
    name = to_name(stream.venue.id)
    Fresh.start_link(endpoint, __MODULE__, state, name: {:local, name})
  end

  @spec to_name(venue_id) :: atom
  def to_name(venue) do
    :"#{__MODULE__}_#{venue}"
  end

  @impl Fresh
  def handle_terminate(close_reason, state) do
    TaiEvents.warning(%Tai.Events.StreamTerminate{venue: state.venue, reason: close_reason})
  end

  @impl Fresh
  def handle_connect(_status, _headers, state) do
    TaiEvents.info(%Tai.Events.StreamConnect{venue: state.venue})
    {:ok, state}
  end

  @impl Fresh
  def handle_disconnect(_code, reason, state) do
    TaiEvents.warning(%Tai.Events.StreamDisconnect{venue: state.venue, reason: reason})
    :reconnect
  end

  @impl Fresh
  def handle_in({:text, msg}, state) do
    received_at = Tai.Time.monotonic_time()

    case Jason.decode(msg) do
      {:ok, decoded} ->
        handle_msg(decoded, received_at, state)
        {:ok, state}

      {:error, _} ->
        {:ok, state}
    end
  end

  def handle_in(_frame, state), do: {:ok, state}

  @impl Fresh
  def handle_control(_frame, state), do: {:ok, state}

  @impl Fresh
  def handle_info(_msg, state), do: {:ok, state}

  @impl Fresh
  def handle_error(_error, _state), do: :reconnect

  defp handle_msg(
         %{
           "type" => "order_book_snapshot",
           "product_symbol" => product_symbol,
           "bids" => bids,
           "asks" => asks
         },
         received_at,
         state
       ) do
    normalized_bids = bids |> normalize_snapshot_changes(:bid)
    normalized_asks = asks |> normalize_snapshot_changes(:ask)

    %OrderBook.ChangeSet{
      venue: state.venue,
      symbol: String.to_atom(product_symbol),
      last_received_at: received_at,
      changes: Enum.concat(normalized_bids, normalized_asks)
    }
    |> OrderBook.replace()
  end

  defp handle_msg(
         %{
           "type" => "trade",
           "id" => id,
           "liquidation" => liquidation,
           "price" => price,
           "product_symbol" => product_symbol,
           "qty" => qty,
           "side" => side,
           "venue_timestamp" => raw_venue_timestamp
         },
         received_at,
         state
       ) do
    {:ok, venue_timestamp, _} = DateTime.from_iso8601(raw_venue_timestamp)
    trade = %Tai.Markets.Trade{
      id: id,
      liquidation: liquidation,
      price: Decimal.new(price),
      product_symbol: String.to_atom(product_symbol),
      qty: Decimal.new(qty),
      received_at: received_at,
      side: side,
      venue: state.venue,
      venue_timestamp: venue_timestamp
    }
    Tai.Markets.publish_trade(trade)
  end

  defp handle_msg(
         %{
           "status" => "open",
           "client_id" => client_id,
           "venue_order_id" => venue_order_id,
           "cumulative_qty" => raw_cumulative_qty,
           "leaves_qty" => raw_leaves_qty
         },
         received_at,
         _state
       ) do
    last_received_at = Tai.Time.monotonic_to_date_time!(received_at)
    cumulative_qty = raw_cumulative_qty |> Tai.Utils.Decimal.cast!()
    leaves_qty = raw_leaves_qty |> Tai.Utils.Decimal.cast!()

    Orders.OrderTransitionWorker.apply(client_id, %{
      venue_order_id: venue_order_id,
      cumulative_qty: cumulative_qty,
      leaves_qty: leaves_qty,
      last_received_at: last_received_at,
      last_venue_timestamp: Timex.now(),
      __type__: :open
    })
  end

  defp handle_msg(
         %{
           "status" => "filled",
           "client_id" => client_id,
           "cumulative_qty" => raw_cumulative_qty
         },
         received_at,
         _state
       ) do
    last_received_at = Tai.Time.monotonic_to_date_time!(received_at)
    cumulative_qty = raw_cumulative_qty |> Tai.Utils.Decimal.cast!()

    Orders.OrderTransitionWorker.apply(client_id, %{
      cumulative_qty: cumulative_qty,
      last_received_at: last_received_at,
      last_venue_timestamp: Timex.now(),
      __type__: :fill
    })
  end

  defp handle_msg(
         %{
           "status" => "canceled",
           "client_id" => client_id
         },
         received_at,
         _state
       ) do
    last_received_at = Tai.Time.monotonic_to_date_time!(received_at)

    Orders.OrderTransitionWorker.apply(client_id, %{
      last_received_at: last_received_at,
      last_venue_timestamp: Timex.now(),
      __type__: :cancel
    })
  end

  defp handle_msg(msg, _received_at, state) do
    TaiEvents.warning(%Tai.Events.StreamMessageUnhandled{
      venue_id: state.venue,
      msg: msg,
      received_at: Timex.now()
    })
  end

  defp normalize_snapshot_changes(venue_price_points, side) do
    venue_price_points
    |> Enum.flat_map(fn {venue_price, venue_size} ->
      with {price, _} <- Decimal.parse(venue_price),
           {size, _} <- Decimal.parse(venue_size) do
        if Decimal.equal?(size, 0) do
          [{:delete, side, price}]
        else
          [{:upsert, side, price, size}]
        end
      else
        :error -> []
      end
    end)
  end
end
