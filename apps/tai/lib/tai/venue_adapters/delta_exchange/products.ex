defmodule Tai.VenueAdapters.DeltaExchange.Products do
  alias Tai.VenueAdapters.DeltaExchange

  def products(venue_id) do
    with {:ok, venue_products} <- fetch_products() do
      products = venue_products |> Enum.map(& DeltaExchange.Product.build(&1, venue_id))
      {:ok, products}
    end
  end

  defp fetch_products do
    case Req.get("https://api.delta.exchange/v2/products") do
      {:ok, %Req.Response{status: 200, body: %{"result" => products}}} ->
        {:ok, products}

      {:ok, %Req.Response{body: body}} ->
        {:error, body}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
