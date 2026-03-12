defmodule Tai.VenueAdapters.OkEx.Stream.Channels do
  @order "order"
  @depth "depth"
  @trade "trade"

  @spec order(Tai.Venues.Product.t()) :: String.t()
  def order(product) do
    build(product, @order)
  end

  @spec depth(Tai.Venues.Product.t()) :: String.t()
  def depth(product) do
    build(product, @depth)
  end

  @spec trade(Tai.Venues.Product.t()) :: String.t()
  def trade(product) do
    build(product, @trade)
  end

  defp build(product, name) do
    prefix = product |> prefix()
    "#{prefix}/#{name}:#{product.venue_symbol}"
  end

  defp prefix(%Tai.Venues.Product{type: :future}), do: :futures
  defp prefix(product), do: product.type
end
