defmodule Tai.VenueAdapters.Deribit.StreamSupervisor do
  use Supervisor

  alias Tai.VenueAdapters.Deribit.Stream.{
    Connection,
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
  def to_name(venue), do: :"#{__MODULE__}_#{venue}"

  def init(stream) do
    credential = stream.venue.credentials |> Map.to_list() |> List.first()

    order_book_children =
      build_order_book_children(
        stream.market_streams,
        stream.venue.quote_depth,
        stream.venue.broadcast_change_set
      )

    process_order_book_children = build_process_order_book_children(stream.market_streams)

    system = [
      {RouteOrderBooks, [venue_id: stream.venue.id, order_books: stream.market_streams]},
      {Connection, [endpoint: endpoint(), stream: stream, credential: credential]}
    ]

    (order_book_children ++ process_order_book_children ++ system)
    |> Supervisor.init(strategy: :one_for_one)
  end

  @default_domain "www.deribit.com"
  @default_api_path "/api/v2"
  defp endpoint do
    domain = Application.get_env(:ex_deribit, :domain, @default_domain)
    api_path = Application.get_env(:ex_deribit, :api_path, @default_api_path)
    "wss://#{domain}/ws#{api_path}"
  end

  defp build_order_book_children(market_streams, quote_depth, broadcast_change_set) do
    market_streams
    |> Enum.map(&OrderBook.child_spec(&1, quote_depth, broadcast_change_set))
  end

  defp build_process_order_book_children(market_streams) do
    market_streams
    |> Enum.map(fn p ->
      %{
        id: ProcessOrderBook.to_name(p.venue_id, p.venue_symbol),
        start: {ProcessOrderBook, :start_link, [p]}
      }
    end)
  end
end
