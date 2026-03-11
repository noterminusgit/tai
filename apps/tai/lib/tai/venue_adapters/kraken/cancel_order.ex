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
        {:ok, %Responses.CancelAccepted{id: order.venue_order_id, received_at: Timex.now()}}

      {:ok, %{"error" => errors}} when errors != [] ->
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
