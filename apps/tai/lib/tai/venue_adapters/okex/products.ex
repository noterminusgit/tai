defmodule Tai.VenueAdapters.OkEx.Products do
  @base_url "https://www.okex.com"

  def products(venue_id) do
    with {:ok, future_instruments} <- fetch_instruments("/api/futures/v3/instruments"),
         {:ok, swap_instruments} <- fetch_instruments("/api/swap/v3/instruments"),
         {:ok, spot_instruments} <- fetch_instruments("/api/spot/v3/instruments") do
      future_products =
        future_instruments |> Enum.map(&Tai.VenueAdapters.OkEx.Product.build(&1, :future, venue_id))

      swap_products =
        swap_instruments |> Enum.map(&Tai.VenueAdapters.OkEx.Product.build(&1, :swap, venue_id))

      spot_products =
        spot_instruments |> Enum.map(&Tai.VenueAdapters.OkEx.Product.build(&1, :spot, venue_id))

      products = future_products ++ swap_products ++ spot_products

      {:ok, products}
    end
  end

  defp fetch_instruments(path) do
    case Req.get("#{@base_url}#{path}") do
      {:ok, %Req.Response{status: 200, body: body}} when is_list(body) ->
        {:ok, body}

      {:ok, %Req.Response{body: body}} ->
        {:error, body}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defdelegate to_symbol(instrument_id), to: Tai.VenueAdapters.OkEx.Product
end
