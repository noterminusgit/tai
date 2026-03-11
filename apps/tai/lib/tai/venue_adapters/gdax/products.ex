defmodule Tai.VenueAdapters.Gdax.Products do
  @moduledoc """
  Hydrates the available products on the GDAX exchange
  """

  @type venue :: Tai.Venue.id()
  @type product :: Tai.Venues.Product.t()
  @type error_reason ::
          :timeout
          | {:credentials, reason :: term}
          | {:service_unavailable, reason :: String.t()}

  @spec products(venue) :: {:ok, [product]} | {:error, error_reason}
  @spec products(atom) :: {:ok, list} | {:error, term}
  def products(venue_id) do
    with {:ok, exchange_products} <- fetch_products() do
      products = Enum.map(exchange_products, &build(&1, venue_id))
      {:ok, products}
    end
  end

  defp fetch_products do
    case Req.get("https://api.exchange.coinbase.com/products") do
      {:ok, %Req.Response{status: 200, body: body}} when is_list(body) ->
        {:ok, body}

      {:ok, %Req.Response{status: 503, body: %{"message" => msg}}} ->
        {:error, {:service_unavailable, msg}}

      {:ok, %Req.Response{status: 503, body: body}} when is_binary(body) ->
        {:error, {:service_unavailable, body}}

      {:ok, %Req.Response{body: %{"message" => "Invalid Passphrase" = reason}}} ->
        {:error, {:credentials, reason}}

      {:ok, %Req.Response{body: %{"message" => "Invalid API Key" = reason}}} ->
        {:error, {:credentials, reason}}

      {:error, %Req.TransportError{reason: :timeout}} ->
        {:error, :timeout}

      {:error, _reason} ->
        {:error, :timeout}
    end
  end

  defp build(
         %{
           "base_currency" => base_currency,
           "quote_currency" => quote_currency,
           "id" => id,
           "status" => exchange_status,
           "base_min_size" => raw_base_min_size,
           "base_max_size" => raw_base_max_size,
           "quote_increment" => raw_quote_increment
         },
         venue_id
       ) do
    symbol = Tai.Symbol.build(base_currency, quote_currency)
    {:ok, status} = Tai.VenueAdapters.Gdax.ProductStatus.normalize(exchange_status)
    base_min_size = raw_base_min_size |> Tai.Utils.Decimal.cast!(:normalize)
    base_max_size = raw_base_max_size |> Tai.Utils.Decimal.cast!(:normalize)
    quote_increment = raw_quote_increment |> Tai.Utils.Decimal.cast!(:normalize)
    min_notional = Decimal.mult(base_min_size, quote_increment) |> Decimal.normalize()

    %Tai.Venues.Product{
      venue_id: venue_id,
      symbol: symbol,
      venue_symbol: id,
      base: base_currency |> downcase_and_atom(),
      quote: quote_currency |> downcase_and_atom(),
      venue_base: base_currency,
      venue_quote: quote_currency,
      status: status,
      type: :spot,
      collateral: false,
      price_increment: quote_increment,
      size_increment: base_min_size,
      min_price: quote_increment,
      min_size: base_min_size,
      min_notional: min_notional,
      max_size: base_max_size,
      value: Decimal.new(1),
      value_side: :base,
      is_quanto: false,
      is_inverse: false
    }
  end

  defp downcase_and_atom(str), do: str |> String.downcase() |> String.to_atom()
end
