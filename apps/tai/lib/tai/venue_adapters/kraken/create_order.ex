defmodule Tai.VenueAdapters.Kraken.CreateOrder do
  @moduledoc """
  Creates orders on Kraken via REST API
  """
  alias Tai.Orders.Responses

  def create_order(order, credentials) do
    endpoint = "https://api.kraken.com/0/private/AddOrder"

    params = build_order_params(order)

    case send_request(endpoint, params, credentials) do
      {:ok, %{"error" => [], "result" => result}} ->
        parse_create_response(result, order)

      {:ok, %{"error" => errors}} when length(errors) > 0 ->
        parse_error(errors)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp build_order_params(order) do
    %{
      "pair" => venue_symbol(order.venue_product_symbol),
      "type" => order.side |> Atom.to_string(),
      "ordertype" => map_order_type(order.type),
      "volume" => order.qty |> Decimal.to_string(:normal),
      "price" => order.price |> Decimal.to_string(:normal)
    }
    |> add_time_in_force(order)
  end

  defp venue_symbol(symbol) when is_binary(symbol), do: symbol
  defp venue_symbol(symbol) when is_atom(symbol), do: Atom.to_string(symbol)

  defp map_order_type(:limit), do: "limit"
  defp map_order_type(:market), do: "market"
  defp map_order_type(_), do: "limit"

  defp add_time_in_force(params, %{time_in_force: :gtc}), do: params
  defp add_time_in_force(params, %{time_in_force: :ioc}), do: Map.put(params, "timeInForce", "IOC")
  defp add_time_in_force(params, %{time_in_force: :fok}), do: Map.put(params, "timeInForce", "FOK")
  defp add_time_in_force(params, %{post_only: true}), do: Map.put(params, "oflags", "post")
  defp add_time_in_force(params, _), do: params

  defp parse_create_response(%{"txid" => [order_id | _]}, order) do
    received_at = Timex.now()

    response = %Responses.CreateAccepted{
      id: order_id,
      status: :open,
      client_id: order.client_id,
      venue_order_id: order_id,
      received_at: received_at
    }

    {:ok, response}
  end

  defp parse_create_response(_, order) do
    {:error, :unknown_response}
  end

  defp parse_error(errors) do
    error_msg = errors |> List.first()

    cond do
      String.contains?(error_msg, "Insufficient funds") ->
        {:error, {:insufficient_balance, error_msg}}

      String.contains?(error_msg, "Order minimum") ->
        {:error, {:size_too_small, error_msg}}

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
