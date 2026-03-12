defmodule Tai.VenueAdapters.Binance.Accounts do
  alias Tai.VenueAdapters.Binance.Auth

  @spec accounts(atom, atom, map) :: {:ok, list} | {:error, term}
  def accounts(venue_id, credential_id, credentials) do
    with {:ok, %Req.Response{status: 200, body: venue_account}} <-
           Auth.signed_request(:get, "/api/v3/account", credentials) do
      accounts =
        venue_account["balances"]
        |> Enum.map(&build(&1, venue_id, credential_id))

      {:ok, accounts}
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

  defp build(
         %{"asset" => raw_asset, "free" => venue_free, "locked" => venue_locked},
         venue_id,
         credential_id
       ) do
    asset =
      raw_asset
      |> String.downcase()
      |> String.to_atom()

    free = venue_free |> Decimal.new() |> Decimal.normalize()
    locked = venue_locked |> Decimal.new() |> Decimal.normalize()
    equity = Decimal.add(free, locked)

    %Tai.Venues.Account{
      venue_id: venue_id,
      credential_id: credential_id,
      asset: asset,
      type: "default",
      equity: equity,
      free: free,
      locked: locked
    }
  end
end
