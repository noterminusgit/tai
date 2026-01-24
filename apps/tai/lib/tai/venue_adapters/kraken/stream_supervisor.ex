defmodule Tai.VenueAdapters.Kraken.StreamSupervisor do
  use Supervisor
  alias Tai.VenueAdapters.Kraken.Stream

  def start_link(stream) do
    name = to_name(stream.venue.id)
    Supervisor.start_link(__MODULE__, stream, name: name)
  end

  def to_name(venue_id), do: :"#{__MODULE__}_#{venue_id}"

  def init(stream) do
    credential = stream.venue.credentials |> Map.to_list() |> List.first()
    quote_depth = Map.get(stream.venue, :quote_depth, 10)
    broadcast_change_set = Map.get(stream.venue, :broadcast_change_set, false)
    market_streams = stream.markets |> Stream.map(& &1.product)

    system_children = [
      {Stream.RouteOrderBooks,
       [
         venue: stream.venue.id,
         order_books: market_streams
       ]},
      {Stream.ProcessOrderBook,
       [
         venue: stream.venue.id
       ]},
      {Stream.ProcessOptionalChannels,
       [
         venue: stream.venue.id,
         products: market_streams
       ]},
      {Stream.Connection,
       [
         venue: stream.venue.id,
         endpoint: endpoint(),
         stream: stream,
         credential: credential,
         products: market_streams
       ]}
    ]

    order_book_children =
      market_streams
      |> Enum.map(fn product ->
        Supervisor.child_spec(
          {Tai.Markets.OrderBook,
           [
             product: product,
             venue_id: stream.venue.id,
             quote_depth: quote_depth,
             broadcast_change_set: broadcast_change_set
           ]},
          id: {Tai.Markets.OrderBook, product}
        )
      end)

    (order_book_children ++ system_children)
    |> Supervisor.init(strategy: :one_for_one)
  end

  defp endpoint, do: "wss://ws.kraken.com/"
end
