defmodule Tai.VenueAdapters.Kraken.CancelOrder do
  @moduledoc """
  Cancels orders on Kraken via REST API
  """
  alias Tai.Orders.Responses

  def cancel_order(order, credentials) do
    endpoint = "https://api.kraken.com/0/private/CancelOrder"

    params = %{
      "txid" => order.venue_order_id
    }

    case send_request(endpoint, params, credentials) do
      {:ok, %{"error" => [], "result" => _result}} ->
        {:ok, %Responses.CancelAccepted{id: order.venue_order_id}}

      {:ok, %{"error" => errors}} when length(errors) > 0 ->
        parse_error(errors)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp parse_error(errors) do
    error_msg = errors |> List.first()

    cond do
      String.contains?(error_msg, "Unknown order") || String.contains?(error_msg, "Invalid order") ->
        {:error, {:not_found, error_msg}}

      true ->
        {:error, {:kraken_error, error_msg}}
    end
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
