defmodule Tai.VenueAdapters.Kraken.Stream.Connection do
  use Tai.Venues.Streams.ConnectionAdapter
  alias Tai.VenueAdapters.Kraken.Stream

  def subscribe(state) do
    send(self(), :subscribe_to_order_books)
    send(self(), :subscribe_to_trades)
    {:ok, state}
  end

  def handle_info(:subscribe_to_order_books, state) do
    # Subscribe to order book channels for all products
    products = state.opts[:products] || []

    products
    |> Enum.each(fn product ->
      product_symbol = product.venue_symbol

      msg =
        %{
          event: "subscribe",
          pair: [product_symbol],
          subscription: %{name: "book", depth: 10}
        }
        |> Jason.encode!()

      send(state.ws_pid, {:send, msg})
    end)

    {:noreply, state}
  end

  def handle_info(:subscribe_to_trades, state) do
    # Subscribe to trade channels for all products
    products = state.opts[:products] || []

    products
    |> Enum.each(fn product ->
      product_symbol = product.venue_symbol

      msg =
        %{
          event: "subscribe",
          pair: [product_symbol],
          subscription: %{name: "trade"}
        }
        |> Jason.encode!()

      send(state.ws_pid, {:send, msg})
    end)

    {:noreply, state}
  end

  def handle_msg(msg, state) do
    case Jason.decode(msg) do
      {:ok, %{"event" => "systemStatus"}} ->
        {:noreply, state}

      {:ok, %{"event" => "subscriptionStatus", "status" => "subscribed"}} ->
        {:noreply, state}

      {:ok, %{"event" => "heartbeat"}} ->
        {:noreply, state}

      {:ok, data} when is_list(data) ->
        handle_channel_data(data, state)

      _ ->
        {:noreply, state}
    end
  end

  defp handle_channel_data([_channel_id, data, channel_name | _rest], state) when is_map(data) do
    cond do
      String.contains?(channel_name, "book") ->
        Stream.ProcessOrderBook.handle_msg(data, state)

      String.contains?(channel_name, "trade") ->
        Stream.ProcessOptionalChannels.handle_msg({:trade, data}, state)

      true ->
        {:noreply, state}
    end
  end

  defp handle_channel_data(_data, state) do
    {:noreply, state}
  end
end
