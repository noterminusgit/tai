defmodule Tai.VenueAdapters.Kraken.Accounts do
  @moduledoc """
  Fetches account balances from Kraken REST API
  """

  def accounts(venue_id, credential_id, credentials) do
    endpoint = "https://api.kraken.com/0/private/Balance"

    case send_request(endpoint, %{}, credentials) do
      {:ok, %{"error" => [], "result" => balances}} ->
        parse_balances(balances, venue_id, credential_id)

      {:ok, %{"error" => errors}} when errors != [] ->
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

    case generate_signature(api_path, nonce, body, credentials.api_secret) do
      {:ok, signature} ->
        headers = [
          {"API-Key", credentials.api_key},
          {"API-Sign", signature},
          {"Content-Type", "application/x-www-form-urlencoded"}
        ]

        case Req.post(endpoint, body: body, headers: headers, decode_body: false) do
          {:ok, %Req.Response{status: 200, body: response_body}} ->
            {:ok, decode_body(response_body)}

          {:ok, %Req.Response{status: status_code}} ->
            {:error, {:http_error, status_code}}

          {:error, %Mint.TransportError{reason: reason}} ->
            {:error, reason}
        end

      {:error, _} = error ->
        error
    end
  end

  defp generate_signature(api_path, nonce, body, api_secret) do
    # Kraken signature generation:
    # base64_decode(API-Secret) used to hash:
    # API-Path + SHA256(nonce + POST data)
    case Base.decode64(api_secret) do
      {:ok, decoded_secret} ->
        nonce_post = nonce <> body
        sha256_hash = :crypto.hash(:sha256, nonce_post)

        message = api_path <> sha256_hash
        hmac = :crypto.mac(:hmac, :sha512, decoded_secret, message)

        {:ok, Base.encode64(hmac)}

      :error ->
        {:error, :invalid_api_secret}
    end
  end

  defp decode_body(body) when is_map(body), do: body
  defp decode_body(body) when is_binary(body), do: Jason.decode!(body)
end
