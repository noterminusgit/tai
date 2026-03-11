defmodule Tai.VenueAdapters.Huobi.Products do
  @spec products(atom) :: {:ok, list} | {:error, term}
  def products(venue_id) do
    with {:ok, future_instruments} <- fetch_contracts() do
      future_products =
        future_instruments |> Enum.map(&Tai.VenueAdapters.Huobi.Product.build(&1, venue_id))

      products = future_products

      {:ok, products}
    end
  end

  defp fetch_contracts do
    case Req.get("https://api.hbdm.com/api/v1/contract_contract_info") do
      {:ok, %Req.Response{status: 200, body: %{"status" => "ok", "data" => data}}} ->
        {:ok, data}

      {:ok, %Req.Response{status: 200, body: body}} when is_binary(body) ->
        case Jason.decode(body) do
          {:ok, %{"status" => "ok", "data" => data}} -> {:ok, data}
          {:ok, other} -> {:error, other}
          {:error, _} -> {:error, body}
        end

      {:ok, %Req.Response{body: body}} ->
        {:error, body}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defdelegate to_symbol(instrument_id), to: Tai.VenueAdapters.Huobi.Product
end
