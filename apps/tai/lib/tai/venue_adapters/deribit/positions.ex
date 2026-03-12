defmodule Tai.VenueAdapters.Deribit.Positions do
  defp domain, do: Application.get_env(:ex_deribit, :domain, "www.deribit.com")

  @spec positions(atom, atom, map) :: {:ok, list} | {:error, term}
  def positions(venue_id, credential_id, credentials) do
    venue_credentials = to_venue_credentials(credentials)

    with {:ok, currencies} <- fetch_currencies(),
         {:ok, venue_positions} <- fetch_venue_positions(currencies, venue_credentials) do
      positions =
        venue_positions
        |> Enum.map(&build(&1, venue_id, credential_id))
        |> Enum.filter(& &1)

      {:ok, positions}
    end
  end

  defdelegate to_venue_credentials(credentials),
    to: Tai.VenueAdapters.Deribit.Credentials,
    as: :from

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

  defp fetch_venue_positions(currencies, venue_credentials) do
    currencies
    |> Enum.reduce(
      {:ok, []},
      fn c, {:ok, existing_venue_positions} ->
        currency = c["currency"]

        case Req.get("https://#{domain()}/api/v2/private/get_positions",
               params: [currency: currency],
               headers: [{"Authorization", "Bearer #{venue_credentials[:access_token]}"}]
             ) do
          {:ok, %Req.Response{status: 200, body: %{"result" => currency_venue_positions}}} ->
            {:ok, existing_venue_positions ++ currency_venue_positions}

          {:ok, %Req.Response{body: body}} ->
            {:error, body}

          {:error, reason} ->
            {:error, reason}
        end
      end
    )
  end

  defdelegate to_symbol(instrument_name),
    to: Tai.VenueAdapters.Deribit.Product

  defp build(%{"direction" => "zero"}, _, _), do: nil

  defp build(venue_position, venue_id, credential_id) do
    product_symbol = venue_position["instrument_name"] |> to_symbol()

    %Tai.Trading.Position{
      venue_id: venue_id,
      credential_id: credential_id,
      product_symbol: product_symbol,
      side: venue_position |> side(),
      qty: venue_position |> qty(),
      entry_price: venue_position |> avg_price(),
      leverage: venue_position |> leverage(),
      margin_mode: :crossed
    }
  end

  defp side(%{"direction" => "buy"}), do: :long
  defp side(%{"direction" => "sell"}), do: :short

  defp qty(%{"size" => size}) when size > 0, do: Tai.Utils.Decimal.cast!(size)
  defp qty(%{"size" => size}) when size < 0, do: Tai.Utils.Decimal.cast!(-size)

  defp avg_price(position), do: Tai.Utils.Decimal.cast!(position["average_price"])

  @zero Decimal.new(0)
  defp leverage(%{"kind" => "option"}), do: @zero
  defp leverage(position), do: Tai.Utils.Decimal.cast!(position["leverage"])
end
