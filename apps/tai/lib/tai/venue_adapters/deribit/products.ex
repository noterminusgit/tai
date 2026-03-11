defmodule Tai.VenueAdapters.Deribit.Products do
  defp domain, do: Application.get_env(:ex_deribit, :domain, "www.deribit.com")

  def products(venue_id) do
    with {:ok, currencies} <- fetch_currencies(),
         {:ok, instruments} <- fetch_instruments(currencies) do
      products =
        instruments
        |> Enum.map(&Tai.VenueAdapters.Deribit.Product.build(&1, venue_id))

      {:ok, products}
    end
  end

  defp fetch_currencies do
    case Req.get("https://#{domain()}/api/v2/public/get_currencies") do
      {:ok, %Req.Response{status: 200, body: %{"result" => currencies}}} ->
        {:ok, currencies}

      {:ok, %Req.Response{body: body}} ->
        {:error, body}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp fetch_instruments(currencies) do
    currencies
    |> Enum.reduce(
      {:ok, []},
      fn c, {:ok, existing_instruments} ->
        currency = c["currency"]

        case Req.get("https://#{domain()}/api/v2/public/get_instruments",
               params: [currency: currency]
             ) do
          {:ok, %Req.Response{status: 200, body: %{"result" => currency_instruments}}} ->
            {:ok, existing_instruments ++ currency_instruments}

          {:ok, %Req.Response{body: body}} ->
            {:error, body}

          {:error, reason} ->
            {:error, reason}
        end
      end
    )
  end
end
