defmodule Tai.VenueAdapters.Kraken.MakerTakerFees do
  @moduledoc """
  Fetches maker/taker fee information from Kraken REST API
  """

  def maker_taker_fees(venue_id, credential_id, credentials) do
    endpoint = "https://api.kraken.com/0/private/TradeVolume"

    case send_request(endpoint, %{}, credentials) do
      {:ok, %{"error" => [], "result" => result}} ->
        parse_fees(result)

      {:ok, %{"error" => errors}} when length(errors) > 0 ->
        {:error, {:kraken_error, errors}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp parse_fees(%{"fees_maker" => maker, "fees" => taker}) do
    # Kraken returns fees as percentages (e.g., 0.16 for 0.16%)
    # Convert to decimal (0.16% = 0.0016)
    maker_fee =
      maker
      |> Map.values()
      |> List.first()
      |> parse_fee_value()

    taker_fee =
      taker
      |> Map.values()
      |> List.first()
      |> parse_fee_value()

    {:ok, {maker_fee, taker_fee}}
  end

  defp parse_fees(_result) do
    # Default fees if structure is different
    {:ok, {Decimal.new("0.0016"), Decimal.new("0.0026")}}
  end

  defp parse_fee_value(nil), do: Decimal.new("0.0016")
  defp parse_fee_value(value) when is_binary(value) do
    {decimal, _} = Decimal.parse(value)
    Decimal.div(decimal, 100)
  end
  defp parse_fee_value(value) when is_number(value) do
    value
    |> Decimal.new()
    |> Decimal.div(100)
  end

  defp send_request(endpoint, params, credentials) do
    nonce = :os.system_time(:millisecond) |> Integer.to_string()
    params_with_nonce = Map.put(params, "nonce", nonce)

    body = URI.encode_query(params_with_nonce)
    api_path = URI.parse(endpoint).path

    signature = generate_signature(api_path, nonce, body, credentials.api_secret)

    headers = [
      {"API-Key", credentials.api_key},
      {"API-Sign", signature},
      {"Content-Type", "application/x-www-form-urlencoded"}
    ]

    case HTTPoison.post(endpoint, body, headers) do
      {:ok, %HTTPoison.Response{status_code: 200, body: response_body}} ->
        {:ok, Jason.decode!(response_body)}

      {:ok, %HTTPoison.Response{status_code: status_code}} ->
        {:error, {:http_error, status_code}}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, reason}
    end
  end

  defp generate_signature(api_path, nonce, body, api_secret) do
    decoded_secret = Base.decode64!(api_secret)

    nonce_post = nonce <> body
    sha256_hash = :crypto.hash(:sha256, nonce_post)

    message = api_path <> sha256_hash
    hmac = :crypto.mac(:hmac, :sha512, decoded_secret, message)

    Base.encode64(hmac)
  end
end
