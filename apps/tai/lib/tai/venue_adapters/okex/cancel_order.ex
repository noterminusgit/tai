defmodule Tai.VenueAdapters.OkEx.CancelOrder do
  @moduledoc """
  Sends a cancel order request to OkEx.

  OkEx uses different API endpoints for each of their
  product types: futures, swap & spot.  API responses
  across these products are inconsistent.
  """

  alias Tai.Orders.Responses

  @base_url "https://www.okex.com"

  @type order :: Tai.Orders.Order.t()
  @type credentials :: Tai.Venues.Adapter.credentials()
  @type response :: Responses.CancelAccepted.t()
  @type reason :: :timeout | :connect_timeout | :not_found

  @spec cancel_order(order, credentials) :: {:ok, response} | {:error, reason}
  @spec cancel_order(Tai.Orders.Order.t(), map) :: {:ok, term} | {:error, term}
  def cancel_order(order, credentials) do
    {order, credentials}
    |> send_to_venue()
    |> parse_response()
  end

  def send_to_venue({order, credentials}) do
    venue_config = credentials |> to_venue_credentials
    venue_symbol = order.venue_product_symbol
    {path, body} = cancel_endpoint_and_body(order, venue_symbol)
    {authenticated_post(path, body, venue_config), order}
  end

  defp cancel_endpoint_and_body(%Tai.Orders.Order{product_type: :future}, venue_symbol) do
    {"/api/futures/v3/cancel_batch_orders/#{venue_symbol}",
     %{order_ids: []}}
  end

  defp cancel_endpoint_and_body(%Tai.Orders.Order{product_type: :swap} = order, venue_symbol) do
    {"/api/swap/v3/cancel_batch_orders/#{venue_symbol}",
     %{order_ids: [order.venue_order_id]}}
  end

  defp cancel_endpoint_and_body(%Tai.Orders.Order{product_type: :spot} = order, venue_symbol) do
    {"/api/spot/v3/cancel_batch_orders",
     [%{instrument_id: venue_symbol, order_ids: [order.venue_order_id]}]}
  end

  defdelegate to_venue_credentials(credentials),
    to: Tai.VenueAdapters.OkEx.Credentials,
    as: :from

  defp parse_response({{:ok, %{"result" => true, "order_ids" => [order_id | _]}}, _order}) do
    received_at = Tai.Time.monotonic_time()
    response = %Responses.CancelAccepted{id: order_id, received_at: received_at}
    {:ok, response}
  end

  defp parse_response({{:ok, %{"result" => "true", "ids" => [order_id | _]}}, _order}) do
    received_at = Tai.Time.monotonic_time()
    response = %Responses.CancelAccepted{id: order_id, received_at: received_at}
    {:ok, response}
  end

  defp parse_response({{:ok, response}, %Tai.Orders.Order{product_type: :spot}}) do
    response
    |> Map.values()
    |> List.flatten()
    |> parse_spot_response()
  end

  defp parse_response({{:ok, %{"result" => false, "error_message" => "error order_ids"}}, _order}) do
    {:error, :not_found}
  end

  defp parse_response({{:ok, %{"result" => "false"}}, _order}) do
    {:error, :not_found}
  end

  defp parse_response({{:error, :timeout}, _order}) do
    {:error, :timeout}
  end

  defp parse_response({{:error, :connect_timeout}, _order}) do
    {:error, :connect_timeout}
  end

  defp parse_spot_response([%{"result" => true, "error_code" => "0", "order_id" => order_id} | _]) do
    received_at = Tai.Time.monotonic_time()
    response = %Responses.CancelAccepted{id: order_id, received_at: received_at}
    {:ok, response}
  end

  defp authenticated_post(path, body, credentials) do
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601()
    method = "POST"
    json_body = Jason.encode!(body)
    message = timestamp <> method <> path <> json_body

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

    case Req.post("#{@base_url}#{path}", headers: headers, body: json_body) do
      {:ok, %Req.Response{status: 200, body: resp_body}} ->
        {:ok, resp_body}

      {:ok, %Req.Response{body: resp_body}} ->
        {:error, resp_body}

      {:error, %Req.TransportError{reason: :timeout}} ->
        {:error, :timeout}

      {:error, %Req.TransportError{reason: :connect_timeout}} ->
        {:error, :connect_timeout}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
