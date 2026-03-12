defmodule Tai.VenueAdapters.Bybit.Product do
  @spec build(map, atom) :: Tai.Venues.Product.t()
  def build(symbol, venue_id) do
    name = symbol["symbol"]
    type = name |> to_type()
    expiry = symbol |> to_expiry(type)
    base_currency = symbol["baseCoin"]
    quote_currency = symbol["quoteCoin"]
    status = symbol["status"]
    symbol_alias = symbol["alias"]

    price_filter = symbol["priceFilter"] || %{}
    lot_size_filter = symbol["lotSizeFilter"] || %{}

    %Tai.Venues.Product{
      venue_id: venue_id,
      symbol: name |> downcase_and_atom(),
      venue_symbol: name,
      alias: symbol_alias,
      base: base_currency |> downcase_and_atom(),
      quote: quote_currency |> downcase_and_atom(),
      venue_base: base_currency,
      venue_quote: quote_currency,
      status: status |> to_status(),
      type: type,
      expiry: expiry,
      collateral: false,
      price_increment: Decimal.new(price_filter["tickSize"] || "0"),
      size_increment: Tai.Utils.Decimal.cast!(lot_size_filter["qtyStep"] || "0"),
      min_price: Decimal.new(price_filter["minPrice"] || "0"),
      min_size: Tai.Utils.Decimal.cast!(lot_size_filter["minOrderQty"] || "0"),
      max_price: Decimal.new(price_filter["maxPrice"] || "0"),
      max_size: Decimal.new(lot_size_filter["maxOrderQty"] || "0"),
      value: Tai.Utils.Decimal.cast!(lot_size_filter["qtyStep"] || "0"),
      value_side: :quote,
      is_quanto: false,
      is_inverse: to_is_inverse(quote_currency, type)
    }
  end

  defp downcase_and_atom(str), do: str |> String.downcase() |> String.to_atom()

  defp to_status("Trading"), do: :trading
  defp to_status(_), do: :unknown

  defp to_type(name) do
    case String.match?(name, ~r/.+\d+$/) do
      true -> :future
      false -> :swap
    end
  end

  @expiry_year ~r/.+(?<year>\d{2,2})$/
  @expiry_month_and_day ~r/.+(?<month>\d{2,2})(?<day>\d{2,2})$/
  @expiry_time Time.new!(8, 0, 0, 0)
  defp to_expiry(symbol, type) do
    name = symbol["symbol"]
    symbol_alias = symbol["alias"]

    case type do
      :future ->
        %{"year" => year_str} = Regex.named_captures(@expiry_year, name)
        %{"month" => month_str, "day" => day_str} = Regex.named_captures(@expiry_month_and_day, symbol_alias || name)
        {year, _} = "20#{year_str}" |> Integer.parse()
        {month, _} = month_str |> Integer.parse()
        {day, _} = day_str |> Integer.parse()
        date = Date.new!(year, month, day)
        DateTime.new!(date, @expiry_time)

      _ ->
        nil
    end
  end

  defp to_is_inverse(_quote_currency, :future), do: true
  defp to_is_inverse("USD", :swap), do: true
  defp to_is_inverse(_, :swap), do: false
end
