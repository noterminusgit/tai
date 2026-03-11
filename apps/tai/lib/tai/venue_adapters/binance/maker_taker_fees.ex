defmodule Tai.VenueAdapters.Binance.MakerTakerFees do
  alias Tai.VenueAdapters.Binance.Auth

  @spec maker_taker_fees(atom, atom, map) :: {:ok, {Decimal.t(), Decimal.t()} | nil} | {:error, term}
  def maker_taker_fees(_venue_id, _credential_id, credentials) do
    with {:ok, %Req.Response{status: 200, body: account}} <-
           Auth.signed_request(:get, "/api/v3/account", credentials) do
      percent_factor = Decimal.new(10_000)
      maker = account["makerCommission"] |> Decimal.new() |> Decimal.div(percent_factor)
      taker = account["takerCommission"] |> Decimal.new() |> Decimal.div(percent_factor)
      {:ok, {maker, taker}}
    else
      {:ok, %Req.Response{body: %{"code" => -1021}}} ->
        {:error, :receive_window}

      {:ok, %Req.Response{body: %{"code" => -2014, "msg" => "API-key format invalid." = reason}}} ->
        {:error, {:credentials, reason}}

      {:error, %Req.TransportError{reason: :timeout}} ->
        {:error, :timeout}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
