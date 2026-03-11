defmodule Tai.VenueAdapters.Binance.CancelOrder do
  alias Tai.Orders.Responses
  alias Tai.VenueAdapters.Binance.Auth

  @spec cancel_order(Tai.Orders.Order.t(), map) :: {:ok, term} | {:error, term}
  def cancel_order(order, credentials) do
    params = %{
      "symbol" => order.venue_product_symbol,
      "orderId" => order.venue_order_id
    }

    Auth.signed_request(:delete, "/api/v3/order", credentials, params)
    |> parse_response()
  end

  defp parse_response({:ok, %Req.Response{status: 200, body: body}}) do
    received_at = Tai.Time.monotonic_time()

    response = %Responses.CancelAccepted{
      id: body["orderId"],
      received_at: received_at
    }

    {:ok, response}
  end

  defp parse_response({:ok, %Req.Response{body: %{"code" => -2011}}}) do
    {:error, :not_found}
  end

  defp parse_response({:error, reason}) do
    {:error, {:unhandled, reason}}
  end
end
