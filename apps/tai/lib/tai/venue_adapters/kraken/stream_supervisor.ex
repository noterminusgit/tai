defmodule Tai.VenueAdapters.Kraken.StreamSupervisor do
  use Supervisor

  alias Tai.VenueAdapters.Kraken.Stream.{
    Connection,
    ProcessOptionalChannels,
    ProcessOrderBook,
    RouteOrderBooks
  }

  alias Tai.Markets.OrderBook

  @type stream :: Tai.Venues.Stream.t()
  @type venue_id :: Tai.Venue.id()

  @spec start_link(stream) :: Supervisor.on_start()
  def start_link(stream) do
    name = to_name(stream.venue.id)
    Supervisor.start_link(__MODULE__, stream, name: name)
  end

  @spec to_name(venue_id) :: atom
  def to_name(venue_id), do: :"#{__MODULE__}_#{venue_id}"

  def init(stream) do
    credential = stream.venue.credentials |> Map.to_list() |> List.first()
    quote_depth = Map.get(stream.venue, :quote_depth, 10)
    broadcast_change_set = Map.get(stream.venue, :broadcast_change_set, false)

    order_book_children =
      build_order_book_children(
        stream.markets,
        quote_depth,
        broadcast_change_set
      )

    process_order_book_children = build_process_order_book_children(stream.markets)

    system_children = [
      {RouteOrderBooks, [venue: stream.venue.id, order_books: stream.markets]},
      {ProcessOptionalChannels, [venue: stream.venue.id]},
      {Connection, [endpoint: endpoint(), stream: stream, credential: credential]}
    ]

    (order_book_children ++ process_order_book_children ++ system_children)
    |> Supervisor.init(strategy: :one_for_one)
  end

  defp endpoint, do: "wss://ws.kraken.com/"

  defp build_order_book_children(markets, quote_depth, broadcast_change_set) do
    markets
    |> Enum.map(&OrderBook.child_spec(&1, quote_depth, broadcast_change_set))
  end

  defp build_process_order_book_children(markets) do
    markets
    |> Enum.map(fn p ->
      %{
        id: ProcessOrderBook.to_name(p.venue_id, p.venue_symbol),
        start: {ProcessOrderBook, :start_link, [p]}
      }
    end)
  end
end
