defmodule Tai.VenueAdapters.Deribit.Accounts do
  defp domain, do: Application.get_env(:ex_deribit, :domain, "www.deribit.com")

  @spec accounts(atom, atom, map) :: {:ok, list} | {:error, term}
  def accounts(venue_id, credential_id, credentials) do
    venue_credentials = credentials |> to_venue_credentials()

    with {:ok, currencies} <- fetch_currencies(),
         {:ok, summaries} <- fetch_summaries(currencies, venue_credentials) do
      accounts = summaries |> Enum.map(&build(&1, venue_id, credential_id))

      {:ok, accounts}
    end
  end

  @zero Decimal.new(0)

  def build(account_summary, venue_id, credential_id) do
    equity = account_summary["equity"] |> Tai.Utils.Decimal.cast!()
    asset = account_summary["currency"] |> String.downcase() |> String.to_atom()

    %Tai.Venues.Account{
      venue_id: venue_id,
      credential_id: credential_id,
      asset: asset,
      type: "default",
      equity: equity,
      free: @zero,
      locked: equity
    }
  end

  defdelegate to_venue_credentials(credentials),
    to: Tai.VenueAdapters.Deribit.Credentials,
    as: :from

  defp fetch_currencies do
    case Req.get("https://#{domain()}/api/v2/public/get_currencies") do
      {:ok, %Req.Response{status: 200, body: %{"result" => currencies}}} ->
        {:ok, currencies}

      {:ok, %Req.Response{body: body}} ->
        {:error, body}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp fetch_summaries(currencies, venue_credentials) do
    currencies
    |> Enum.reduce(
      {:ok, []},
      fn c, {:ok, existing_summaries} ->
        currency = c["currency"]

        case Req.get("https://#{domain()}/api/v2/private/get_account_summary",
               params: [currency: currency],
               headers: [{"Authorization", "Bearer #{venue_credentials[:access_token]}"}]
             ) do
          {:ok, %Req.Response{status: 200, body: %{"result" => currency_summary}}} ->
            {:ok, existing_summaries ++ [currency_summary]}

          {:ok, %Req.Response{body: body}} ->
            {:error, body}

          {:error, reason} ->
            {:error, reason}
        end
      end
    )
  end
end
