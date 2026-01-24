defmodule Tai.VenueAdapters.Kraken.Stream.RouteOrderBooks do
  use GenServer

  defmodule State do
    @type venue_id :: Tai.Venue.id()
    @type product_symbol :: Tai.Venues.Product.symbol()
    @type t :: %State{
            venue: venue_id,
            order_books: [product_symbol]
          }

    defstruct ~w[venue order_books]a
  end

  def start_link(args) do
    venue = Keyword.fetch!(args, :venue)
    order_books = Keyword.fetch!(args, :order_books)

    state = %State{venue: venue, order_books: order_books}
    name = venue |> to_name()

    GenServer.start_link(__MODULE__, state, name: name)
  end

  @spec to_name(State.venue_id()) :: atom
  def to_name(venue), do: :"#{__MODULE__}_#{venue}"

  def init(state) do
    {:ok, state}
  end
end
