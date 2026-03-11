defmodule Tai.VenueAdapters.Kraken.Products do
  @moduledoc """
  Fetches product information from Kraken REST API
  """

  @spec products(atom) :: {:ok, list} | {:error, term}
  def products(venue_id) do
    endpoint = "https://api.kraken.com/0/public/AssetPairs"

    case Req.get(endpoint) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        body
        |> decode_body()
        |> parse_products(venue_id)

      {:ok, %Req.Response{status: status_code}} ->
        {:error, {:http_error, status_code}}

      {:error, %Mint.TransportError{reason: reason}} ->
        {:error, reason}
    end
  end

  defp parse_products(%{"error" => [], "result" => pairs}, venue_id) do
    products =
      pairs
      |> Enum.filter(fn {_key, pair} ->
        # Filter out dark pool pairs (ending in .d)
        !String.ends_with?(Map.get(pair, "wsname", ""), ".d")
      end)
      |> Enum.map(fn {_key, pair} ->
        build_product(pair, venue_id)
      end)
      |> Enum.reject(&is_nil/1)

    {:ok, products}
  end

  defp parse_products(%{"error" => errors}, _venue_id) when errors != [] do
    {:error, {:kraken_error, errors}}
  end

  defp build_product(pair, venue_id) do
    wsname = Map.get(pair, "wsname")
    base = Map.get(pair, "base")
    quote = Map.get(pair, "quote")

    if wsname && base && quote do
      # Convert wsname to tai product symbol format (e.g., "XBT/USD" -> "xbt_usd")
      product_symbol = wsname
        |> String.downcase()
        |> String.replace("/", "_")
        |> String.to_atom()

      %Tai.Venues.Product{
        venue_id: venue_id,
        symbol: product_symbol,
        venue_symbol: wsname,
        base: base |> normalize_asset(),
        quote: quote |> normalize_asset(),
        venue_base: base,
        venue_quote: quote,
        status: map_status(pair),
        type: :spot,
        collateral: false,
        value: Decimal.new(1),
        value_side: :quote,
        is_quanto: false,
        is_inverse: false,
        maker_fee: parse_decimal(pair["fees_maker"], 0),
        taker_fee: parse_decimal(pair["fees"], 0),
        min_notional: parse_decimal(pair["ordermin"], 0),
        min_price: Decimal.new(0),
        min_size: parse_decimal(pair["ordermin"], 0),
        price_increment: parse_decimal(pair["tick_size"], "0.01"),
        size_increment: parse_decimal(pair["lot_decimals"], 8)
      }
    else
      nil
    end
  end

  defp normalize_asset(asset) do
    # Kraken uses XXBT for BTC, ZUSD for USD, etc.
    asset
    |> String.replace(~r/^X/, "")
    |> String.replace(~r/^Z/, "")
    |> String.downcase()
    |> String.to_atom()
  end

  defp map_status(%{"status" => "online"}), do: :trading
  defp map_status(_), do: :halt_trading

  defp parse_decimal(nil, default), do: Decimal.new(default)
  defp parse_decimal(value, _default) when is_binary(value) do
    case Decimal.parse(value) do
      {decimal, _} -> decimal
      :error -> Decimal.new(0)
    end
  end
  defp parse_decimal(value, _default) when is_number(value), do: Decimal.new(value)
  defp parse_decimal(_value, default), do: Decimal.new(default)

  defp decode_body(body) when is_map(body), do: body
  defp decode_body(body) when is_binary(body), do: Jason.decode!(body)
end
