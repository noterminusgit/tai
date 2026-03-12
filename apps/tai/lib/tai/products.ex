defmodule Tai.Products do
  alias __MODULE__

  @spec product_symbols_by_venue :: %{atom => [atom]}
  def product_symbols_by_venue do
    Products.Queries.ProductSymbolsByVenue.call()
  end
end
