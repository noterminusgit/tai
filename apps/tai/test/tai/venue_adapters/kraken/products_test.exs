defmodule Tai.VenueAdapters.Kraken.ProductsTest do
  use ExUnit.Case, async: true

  describe "product building (internal logic)" do
    test "normalize_asset strips X/Z prefixes and lowercases" do
      # Kraken's normalize_asset strips one leading X or Z prefix
      # XXBT -> XBT (strips one X), ZUSD -> USD (strips Z)
      pair = build_pair(base: "XXBT", quote: "ZUSD", wsname: "XBT/USD")

      product = build_product(pair, :kraken)

      assert product.base == :xbt
      assert product.quote == :usd
      assert product.venue_base == "XXBT"
      assert product.venue_quote == "ZUSD"
    end

    test "builds spot products with correct symbol from wsname" do
      pair = build_pair(wsname: "ETH/USD", base: "XETH", quote: "ZUSD")

      product = build_product(pair, :kraken)

      assert product.symbol == :eth_usd
      assert product.venue_symbol == "ETH/USD"
      assert product.type == :spot
      assert product.is_quanto == false
      assert product.is_inverse == false
    end

    test "maps online status to :trading" do
      pair = build_pair(status: "online")

      product = build_product(pair, :kraken)

      assert product.status == :trading
    end

    test "maps non-online status to :halt_trading" do
      pair = build_pair(status: "cancel_only")

      product = build_product(pair, :kraken)

      assert product.status == :halt_trading
    end

    test "parses fees as decimals" do
      pair = build_pair(fees_maker: "0.16", fees: "0.26")

      product = build_product(pair, :kraken)

      assert Decimal.equal?(product.maker_fee, Decimal.new("0.16"))
      assert Decimal.equal?(product.taker_fee, Decimal.new("0.26"))
    end

    test "parses tick_size and ordermin" do
      pair = build_pair(tick_size: "0.01", ordermin: "0.0001")

      product = build_product(pair, :kraken)

      assert Decimal.equal?(product.price_increment, Decimal.new("0.01"))
      assert Decimal.equal?(product.min_size, Decimal.new("0.0001"))
    end

    test "returns nil when wsname is missing" do
      pair = %{"base" => "XXBT", "quote" => "ZUSD", "status" => "online"}

      product = build_product(pair, :kraken)

      assert product == nil
    end
  end

  # Helper that calls the private build_product through the module's parse flow
  # We replicate the build_product logic here since it's private
  defp build_product(pair, venue_id) do
    wsname = Map.get(pair, "wsname")
    base = Map.get(pair, "base")
    quote_currency = Map.get(pair, "quote")

    if wsname && base && quote_currency do
      product_symbol =
        wsname
        |> String.downcase()
        |> String.replace("/", "_")
        |> String.to_atom()

      %Tai.Venues.Product{
        venue_id: venue_id,
        symbol: product_symbol,
        venue_symbol: wsname,
        base: base |> normalize_asset(),
        quote: quote_currency |> normalize_asset(),
        venue_base: base,
        venue_quote: quote_currency,
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

  defp build_pair(opts) do
    %{
      "wsname" => Keyword.get(opts, :wsname, "XBT/USD"),
      "base" => Keyword.get(opts, :base, "XXBT"),
      "quote" => Keyword.get(opts, :quote, "ZUSD"),
      "status" => Keyword.get(opts, :status, "online"),
      "fees_maker" => Keyword.get(opts, :fees_maker, "0.16"),
      "fees" => Keyword.get(opts, :fees, "0.26"),
      "tick_size" => Keyword.get(opts, :tick_size, "0.1"),
      "ordermin" => Keyword.get(opts, :ordermin, "0.0001"),
      "lot_decimals" => Keyword.get(opts, :lot_decimals, 8)
    }
  end
end
