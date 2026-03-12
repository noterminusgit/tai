defmodule Tai.VenueAdapters.Bitmex.Products do
  alias Tai.VenueAdapters.Bitmex.HTTPClient

  @spec products(atom) :: {:ok, list} | {:error, term}
  def products(venue_id) do
    get_paginated_products([], venue_id, 0)
  end

  defdelegate to_symbol(venue_symbol),
    to: Tai.VenueAdapters.Bitmex.Product,
    as: :downcase_and_atom

  @count 500
  defp get_paginated_products(acc, venue_id, start) do
    case HTTPClient.get_unauthenticated("/api/v1/instrument", %{start: start, count: @count}) do
      {:ok, []} ->
        {:ok, acc}

      {:ok, instruments} ->
        products =
          instruments
          |> Enum.map(&Tai.VenueAdapters.Bitmex.Product.build(&1, venue_id))
          |> Enum.filter(& &1)

        get_paginated_products(acc ++ products, venue_id, start + @count)

      {:error, reason} ->
        {:error, reason}
    end
  end
end
