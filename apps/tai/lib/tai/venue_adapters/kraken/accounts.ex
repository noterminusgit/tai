defmodule Tai.VenueAdapters.Kraken.Accounts do
  @moduledoc """
  Fetches account balances from Kraken REST API
  """

  def accounts(venue_id, credential_id, credentials) do
    endpoint = "https://api.kraken.com/0/private/Balance"

    case send_request(endpoint, %{}, credentials) do
      {:ok, %{"error" => [], "result" => balances}} ->
        parse_balances(balances, venue_id, credential_id)

      {:ok, %{"error" => errors}} when length(errors) > 0 ->
        {:error, {:kraken_error, errors}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp parse_balances(balances, venue_id, credential_id) do
    accounts =
      balances
      |> Enum.map(fn {asset, balance} ->
        %Tai.Venues.Account{
          venue_id: venue_id,
          credential_id: credential_id,
          asset: normalize_asset(asset),
          type: "default",
          equity: Decimal.new(balance),
          free: Decimal.new(balance),
          locked: Decimal.new(0)
        }
      end)

    {:ok, accounts}
  end

  defp normalize_asset(asset) do
    asset
    |> String.replace(~r/^X/, "")
    |> String.replace(~r/^Z/, "")
    |> String.downcase()
    |> String.to_atom()
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
    # Kraken signature generation:
    # base64_decode(API-Secret) used to hash:
    # API-Path + SHA256(nonce + POST data)
    decoded_secret = Base.decode64!(api_secret)

    nonce_post = nonce <> body
    sha256_hash = :crypto.hash(:sha256, nonce_post)

    message = api_path <> sha256_hash
    hmac = :crypto.mac(:hmac, :sha512, decoded_secret, message)

    Base.encode64(hmac)
  end
end
