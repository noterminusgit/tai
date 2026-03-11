defmodule Tai.VenueAdapters.Binance.CreateOrder do
  @moduledoc """
  Create orders for the Binance adapter
  """

  alias Tai.VenueAdapters.Binance.Auth

  @limit "LIMIT"

  @spec create_order(Tai.Orders.Order.t(), map) :: {:ok, term} | {:error, term}
  def create_order(%Tai.Orders.Order{side: side, type: :limit} = order, credentials) do
    venue_time_in_force = order.time_in_force |> to_venue_time_in_force
    venue_side = side |> Atom.to_string() |> String.upcase()

    params = %{
      "newClientOrderId" => order.client_id,
      "symbol" => order.venue_product_symbol,
      "side" => venue_side,
      "type" => @limit,
      "quantity" => to_string(order.qty),
      "quoteOrderQty" => to_string(order.qty),
      "price" => to_string(order.price),
      "timeInForce" => venue_time_in_force
    }

    Auth.signed_request(:post, "/api/v3/order", credentials, params)
    |> parse_response(order)
  end

  defp to_venue_time_in_force(:gtc), do: "GTC"
  defp to_venue_time_in_force(:fok), do: "FOK"
  defp to_venue_time_in_force(:ioc), do: "IOC"

  defp parse_response({:ok, %Req.Response{status: 200, body: body}}, _) do
    received_at = Tai.Time.monotonic_time()

    venue_timestamp =
      body["transactTime"] |> DateTime.from_unix!(:millisecond)

    venue_order_id = body["orderId"] |> Integer.to_string()

    response = %Tai.Orders.Responses.CreateAccepted{
      id: venue_order_id,
      venue_timestamp: venue_timestamp,
      received_at: received_at
    }

    {:ok, response}
  end

  defp parse_response({:error, %Req.TransportError{reason: :timeout}}, _) do
    {:error, :timeout}
  end

  defp parse_response({:error, %Req.TransportError{reason: :connect_timeout}}, _) do
    {:error, :connect_timeout}
  end

  defp parse_response(
         {:ok, %Req.Response{body: %{"code" => _code, "msg" => "Account has insufficient balance" <> _ = _msg}}},
         _
       ) do
    {:error, :insufficient_balance}
  end

  defp parse_response({:ok, %Req.Response{body: %{"code" => _code, "msg" => msg}}}, _) do
    {:error, {:unhandled, msg}}
  end

  defp parse_response({:error, reason}, _) do
    {:error, {:unhandled, reason}}
  end
end
