defmodule Tai.Venues.Streams.ConnectionAdapter do
  alias __MODULE__

  @type state :: ConnectionAdapter.State.t()
  @type msg :: term
  @type received_at :: integer
  @type phase :: :init | atom

  @callback on_terminate(reason :: term, state) :: {:ok, state} | term
  @callback on_connect(status :: term, headers :: term, state) :: {:ok, state}
  @callback on_disconnect(code :: non_neg_integer | nil, reason :: binary | nil, state) ::
              {:ok, state}
  @callback on_msg(msg, received_at, state) :: {:ok, state}
  @callback subscribe(phase, state) :: {:ok, state}

  defmodule Requests do
    @type next_request_id :: non_neg_integer
    @type t :: %Requests{
            next_request_id: next_request_id,
            pending_requests: %{
              optional(next_request_id) => pos_integer
            }
          }

    @enforce_keys ~w[next_request_id pending_requests]a
    defstruct ~w[next_request_id pending_requests]a
  end

  defmodule State do
    @type channel_name :: atom
    @type route :: :auth | :markets | :optional_channels
    @type t :: %State{
            venue: Tai.Venue.id(),
            routes: %{required(route) => atom},
            channels: [channel_name],
            credential: {Tai.Venue.credential_id(), map} | nil,
            markets: [Tai.Venues.Product.t()],
            quote_depth: pos_integer,
            heartbeat_interval: pos_integer,
            heartbeat_timeout: pos_integer,
            heartbeat_timer: reference | nil,
            heartbeat_timeout_timer: reference | nil,
            compression: :unzip | :gunzip | nil,
            requests: Requests.t() | nil,
            opts: map
          }

    @enforce_keys ~w[
      venue
      routes
      channels
      markets
      quote_depth
      heartbeat_interval
      heartbeat_timeout
      opts
    ]a
    defstruct ~w[
      venue
      routes
      channels
      credential
      markets
      quote_depth
      heartbeat_interval
      heartbeat_timeout
      heartbeat_timer
      heartbeat_timeout_timer
      compression
      requests
      opts
    ]a
  end

  defmodule Events do
    def connect(venue) do
      TaiEvents.info(%Tai.Events.StreamConnect{venue: venue})
    end

    def disconnect(reason, venue) do
      TaiEvents.warning(%Tai.Events.StreamDisconnect{
        venue: venue,
        reason: reason
      })
    end

    def terminate(close_reason, venue) do
      TaiEvents.warning(%Tai.Events.StreamTerminate{venue: venue, reason: close_reason})
    end
  end

  defmodule Topics do
    @topic {:venues, :stream}

    def broadcast(venue, status) do
      :ok = Tai.SystemBus.broadcast(@topic, {@topic, status, venue})
    end
  end

  defmacro __using__(_) do
    quote location: :keep do
      @behaviour Fresh
      @behaviour Tai.Venues.Streams.ConnectionAdapter

      @type venue :: Tai.Venue.id()

      @spec process_name(venue) :: atom
      def process_name(venue), do: :"#{__MODULE__}_#{venue}"

      @impl Fresh
      def handle_connect(_status, _headers, state) do
        Process.flag(:trap_exit, true)
        Topics.broadcast(state.venue, :connect)
        Events.connect(state.venue)
        send(self(), {:heartbeat, :start})
        send(self(), {:subscribe, :init})
        on_connect(_status, _headers, state)
      end

      @impl Fresh
      def handle_disconnect(code, reason, state) do
        Topics.broadcast(state.venue, :disconnect)
        Events.disconnect({code, reason}, state.venue)
        on_disconnect(code, reason, state)
        :reconnect
      end

      @impl Fresh
      def handle_terminate(close_reason, state) do
        Topics.broadcast(state.venue, :terminate)
        Events.terminate(close_reason, state.venue)
        on_terminate(close_reason, state)
      end

      @impl Fresh
      def handle_in({:binary, <<43, 200, 207, 75, 7, 0>> = pong}, state) do
        msg_received_at = received_at()

        :zlib
        |> apply(state.compression, [pong])
        |> on_msg(msg_received_at, state)
      end

      @impl Fresh
      def handle_in({:binary, compressed_data}, state) do
        msg_received_at = received_at()

        compressed_data
        |> then(&:zlib |> apply(state.compression, [&1]))
        |> Jason.decode()
        |> case do
          {:ok, decoded} -> on_msg(decoded, msg_received_at, state)
          {:error, _} -> {:ok, state}
        end
      end

      @impl Fresh
      def handle_in({:text, msg}, state) do
        msg_received_at = received_at()

        case Jason.decode(msg) do
          {:ok, decoded} -> on_msg(decoded, msg_received_at, state)
          {:error, _} -> {:ok, state}
        end
      end

      @impl Fresh
      def handle_control({:pong, _}, state) do
        state =
          state
          |> cancel_heartbeat_timeout()
          |> schedule_heartbeat()

        {:ok, state}
      end

      def handle_control(_frame, state), do: {:ok, state}

      @impl Fresh
      def handle_info({:EXIT, _pid, :normal}, state) do
        {:ok, state}
      end

      @impl Fresh
      def handle_info({:heartbeat, :start}, state) do
        {:ok, schedule_heartbeat(state)}
      end

      @impl Fresh
      def handle_info({:heartbeat, :ping}, state) do
        {:reply, {:ping, ""}, schedule_heartbeat_timeout(state)}
      end

      @impl Fresh
      def handle_info({:heartbeat, :timeout}, state) do
        {:close, 1000, "heartbeat timeout", state}
      end

      @impl Fresh
      def handle_info({:subscribe, phase}, state) do
        subscribe(phase, state)
      end

      @impl Fresh
      def handle_info({:send_msg, msg}, state) do
        json_msg = Jason.encode!(msg)
        {:reply, {:text, json_msg}, state}
      end

      def handle_info(_msg, state), do: {:ok, state}

      @impl Fresh
      def handle_error(_error, _state), do: :reconnect

      def on_terminate(_, state), do: {:ok, state}
      def on_connect(_, _, state), do: {:ok, state}
      def on_disconnect(_, _, state), do: {:ok, state}
      def on_msg(_, _, state), do: {:ok, state}
      def subscribe(_, state), do: {:ok, state}

      defoverridable on_terminate: 2,
                     on_connect: 3,
                     on_disconnect: 3,
                     on_msg: 3,
                     subscribe: 2,
                     handle_connect: 3,
                     handle_disconnect: 3,
                     handle_terminate: 2,
                     handle_in: 2,
                     handle_control: 2,
                     handle_info: 2,
                     handle_error: 2

      defp received_at, do: Tai.Time.monotonic_time()

      defp schedule_heartbeat(state) do
        timer = Process.send_after(self(), {:heartbeat, :ping}, state.heartbeat_interval)
        %{state | heartbeat_timer: timer}
      end

      defp schedule_heartbeat_timeout(state) do
        timer = Process.send_after(self(), {:heartbeat, :timeout}, state.heartbeat_timeout)
        %{state | heartbeat_timeout_timer: timer}
      end

      defp cancel_heartbeat_timeout(state) do
        Process.cancel_timer(state.heartbeat_timeout_timer)
        %{state | heartbeat_timeout_timer: nil}
      end

      defp add_request(state) do
        pending_requests =
          Map.put(state.requests, state.requests.next_request_id, System.monotonic_time())

        requests = %{
          state.requests
          | next_request_id: state.requests.next_request_id + 1,
            pending_requests: pending_requests
        }

        %{state | requests: requests}
      end
    end
  end
end
