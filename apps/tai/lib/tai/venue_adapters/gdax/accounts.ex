defmodule Tai.VenueAdapters.Gdax.Accounts do
  @spec accounts(atom, atom, map) :: {:ok, list} | {:error, term}
  def accounts(venue_id, credential_id, credentials) do
    with {:ok, venue_accounts} <- fetch_accounts(credentials) do
      accounts =
        venue_accounts
        |> Enum.map(&build(&1, venue_id, credential_id))

      {:ok, accounts}
    else
      {:error, "Invalid Passphrase" = reason, _status} ->
        {:error, {:credentials, reason}}

      {:error, "Invalid API Key" = reason, _status} ->
        {:error, {:credentials, reason}}

      {:error, reason, 503} ->
        {:error, {:service_unavailable, reason}}

      {:error, "timeout"} ->
        {:error, :timeout}
    end
  end

  defp fetch_accounts(credentials) do
    method = "GET"
    path = "/accounts"
    timestamp = :os.system_time(:second) |> Integer.to_string()
    body = ""

    message = timestamp <> method <> path <> body
    decoded_secret = Base.decode64!(credentials.api_secret)
    signature = :crypto.mac(:hmac, :sha256, decoded_secret, message) |> Base.encode64()

    headers = [
      {"CB-ACCESS-KEY", credentials.api_key},
      {"CB-ACCESS-SIGN", signature},
      {"CB-ACCESS-TIMESTAMP", timestamp},
      {"CB-ACCESS-PASSPHRASE", credentials.api_passphrase},
      {"Content-Type", "application/json"}
    ]

    case Req.get("https://api.exchange.coinbase.com#{path}", headers: headers) do
      {:ok, %Req.Response{status: 200, body: body}} when is_list(body) ->
        {:ok, body}

      {:ok, %Req.Response{status: 503, body: %{"message" => msg}}} ->
        {:error, msg, 503}

      {:ok, %Req.Response{status: 503, body: body}} when is_binary(body) ->
        {:error, body, 503}

      {:ok, %Req.Response{body: %{"message" => message}, status: status}} ->
        {:error, message, status}

      {:error, %Req.TransportError{reason: :timeout}} ->
        {:error, "timeout"}

      {:error, _reason} ->
        {:error, "timeout"}
    end
  end

  def build(
        %{"currency" => raw_currency, "available" => available, "hold" => hold},
        venue_id,
        credential_id
      ) do
    asset =
      raw_currency
      |> String.downcase()
      |> String.to_atom()

    free = available |> Decimal.new() |> Decimal.normalize()
    locked = hold |> Decimal.new() |> Decimal.normalize()
    equity = Decimal.add(free, locked)

    %Tai.Venues.Account{
      venue_id: venue_id,
      credential_id: credential_id,
      type: "default",
      asset: asset,
      equity: equity,
      free: free,
      locked: locked
    }
  end
end
