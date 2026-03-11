defmodule Tai.VenueAdapters.OkEx.Positions do
  @base_url "https://www.okex.com"

  @spec positions(atom, atom, map) :: {:ok, list} | {:error, term}
  def positions(venue_id, credential_id, credentials) do
    venue_credentials = to_venue_credentials(credentials)

    with {:ok, swap_venue_positions} <- authenticated_get("/api/swap/v3/position", venue_credentials),
         {:ok, futures_venue_positions} <- authenticated_get("/api/futures/v3/position", venue_credentials) do
      swap_positions = swap_venue_positions |> Enum.map(&build_swap(&1, venue_id, credential_id))

      futures_positions =
        futures_venue_positions |> Enum.flat_map(&build_futures(&1, venue_id, credential_id))

      positions = swap_positions ++ futures_positions

      {:ok, positions}
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp to_venue_credentials(credentials), do: Map.new(credentials)

  def build_swap(venue_position, venue_id, credential_id) do
    %Tai.Trading.Position{
      venue_id: venue_id,
      credential_id: credential_id,
      product_symbol: venue_position |> product_symbol(),
      side: venue_position |> swap_side(),
      qty: venue_position["position"] |> Decimal.new(),
      entry_price: venue_position["avg_cost"] |> Decimal.new(),
      margin_mode: venue_position |> margin_mode(),
      leverage: venue_position |> leverage()
    }
  end

  defp build_futures(venue_position, venue_id, credential_id) do
    [
      build_long_future(venue_position, venue_id, credential_id),
      build_short_future(venue_position, venue_id, credential_id)
    ]
  end

  def build_long_future(venue_position, venue_id, credential_id) do
    %Tai.Trading.Position{
      venue_id: venue_id,
      credential_id: credential_id,
      product_symbol: venue_position |> product_symbol(),
      side: :long,
      qty: venue_position |> futures_qty(:long),
      entry_price: venue_position |> futures_entry_price(:long),
      margin_mode: venue_position |> margin_mode(),
      leverage: venue_position |> leverage()
    }
  end

  def build_short_future(venue_position, venue_id, credential_id) do
    %Tai.Trading.Position{
      venue_id: venue_id,
      credential_id: credential_id,
      product_symbol: venue_position |> product_symbol(),
      side: :short,
      qty: venue_position |> futures_qty(:short),
      entry_price: venue_position |> futures_entry_price(:short),
      margin_mode: venue_position |> margin_mode(),
      leverage: venue_position |> leverage()
    }
  end

  # TODO: This should come from products
  defp product_symbol(venue_position) do
    venue_position["instrument_id"]
    |> String.downcase()
    |> String.to_atom()
  end

  defp swap_side(%{"side" => "long"}), do: :long
  defp swap_side(%{"side" => "short"}), do: :short

  defp futures_qty(%{"long_qty" => q}, :long), do: Decimal.new(q)
  defp futures_qty(%{"short_qty" => q}, :short), do: Decimal.new(q)

  defp futures_entry_price(%{"long_avg_cost" => p}, :long), do: Decimal.new(p)
  defp futures_entry_price(%{"short_avg_cost" => p}, :short), do: Decimal.new(p)

  defp margin_mode(%{"margin_mode" => "crossed"}), do: :crossed
  defp margin_mode(%{"margin_mode" => "fixed"}), do: :fixed
  defp margin_mode(_), do: :crossed

  defp leverage(venue_position), do: venue_position["leverage"] |> Decimal.new()

  defp authenticated_get(path, credentials) do
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601()
    method = "GET"
    body = ""
    message = timestamp <> method <> path <> body

    decoded_secret =
      case Base.decode64(credentials[:api_secret]) do
        {:ok, secret} -> secret
        :error -> raise ArgumentError, "invalid base64 in api_secret credential"
      end

    signature = :crypto.mac(:hmac, :sha256, decoded_secret, message) |> Base.encode64()

    headers = [
      {"OK-ACCESS-KEY", credentials[:api_key]},
      {"OK-ACCESS-SIGN", signature},
      {"OK-ACCESS-TIMESTAMP", timestamp},
      {"OK-ACCESS-PASSPHRASE", credentials[:api_passphrase]},
      {"Content-Type", "application/json"}
    ]

    case Req.get("#{@base_url}#{path}", headers: headers) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %Req.Response{body: body}} ->
        {:error, body}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
