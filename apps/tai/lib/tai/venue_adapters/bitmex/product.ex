defmodule Tai.VenueAdapters.Bitmex.Product do
  @format "{ISO:Extended}"

  @spec build(map, atom) :: Tai.Venues.Product.t() | nil
  def build(%{"lotSize" => nil}, _), do: nil

  def build(instrument, venue_id) do
    symbol = instrument["symbol"] |> downcase_and_atom
    type = instrument["expiry"] |> type()
    status = Tai.VenueAdapters.Bitmex.ProductStatus.normalize(instrument["state"])
    listing = instrument["listing"] && Timex.parse!(instrument["listing"], @format)
    expiry = instrument["expiry"] && Timex.parse!(instrument["expiry"], @format)
    lot_size = instrument["lotSize"] |> Tai.Utils.Decimal.cast!()
    tick_size = instrument["tickSize"] |> Tai.Utils.Decimal.cast!()
    max_order_qty = instrument["maxOrderQty"] && instrument["maxOrderQty"] |> Tai.Utils.Decimal.cast!()
    max_price = instrument["maxPrice"] && instrument["maxPrice"] |> Tai.Utils.Decimal.cast!()
    maker_fee = instrument["makerFee"] && instrument["makerFee"] |> Tai.Utils.Decimal.cast!()
    taker_fee = instrument["takerFee"] && instrument["takerFee"] |> Tai.Utils.Decimal.cast!()

    %Tai.Venues.Product{
      venue_id: venue_id,
      symbol: symbol,
      venue_symbol: instrument["symbol"],
      base: instrument["underlying"] |> downcase_and_atom(),
      quote: instrument["quoteCurrency"] |> downcase_and_atom(),
      venue_base: instrument["underlying"],
      venue_quote: instrument["quoteCurrency"],
      status: status,
      type: type,
      listing: listing,
      expiry: expiry,
      collateral: false,
      price_increment: tick_size,
      size_increment: lot_size,
      min_price: tick_size,
      min_size: Decimal.new(1),
      max_price: max_price,
      max_size: max_order_qty,
      value: lot_size,
      value_side: :quote,
      is_quanto: instrument["isQuanto"],
      is_inverse: instrument["isInverse"],
      maker_fee: maker_fee,
      taker_fee: taker_fee
    }
  end

  def downcase_and_atom(str), do: str |> String.downcase() |> String.to_atom()

  defp type(nil), do: :swap
  defp type(_), do: :future
end
