defmodule Tai.VenueAdapters.Bybit.Products do
  alias Tai.VenueAdapters.Bybit.Product

  def products(venue_id) do
    with {:ok, derivative_symbols} <- fetch_symbols() do
      products = derivative_symbols |> Enum.map(&Product.build(&1, venue_id))
      {:ok, products}
    end
  end

  defp fetch_symbols do
    case Req.get("https://api.bybit.com/v5/market/instruments-info", params: [category: "linear"]) do
      {:ok, %Req.Response{status: 200, body: %{"result" => %{"list" => symbols}}}} ->
        {:ok, symbols}

      {:ok, %Req.Response{body: body}} ->
        {:error, body}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
