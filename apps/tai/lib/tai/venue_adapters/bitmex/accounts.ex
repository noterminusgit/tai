defmodule Tai.VenueAdapters.Bitmex.Accounts do
  alias Tai.VenueAdapters.Bitmex.HTTPClient

  @type venue_id :: Tai.Venue.id()
  @type account :: Tai.Venues.Account.t()
  @type credential_id :: Tai.Venue.credential_id()
  @type credentials :: Tai.Venue.credentials()
  @type shared_error_reason :: Tai.Venues.Adapter.shared_error_reason()

  @spec accounts(venue_id, credential_id, credentials) ::
          {:ok, [account]} | {:error, shared_error_reason}
  @spec accounts(atom, atom, map) :: {:ok, list} | {:error, term}
  def accounts(venue_id, credential_id, credentials) do
    venue_credentials = to_venue_credentials(credentials)

    with {:ok, margin, _rate_limit} <-
           HTTPClient.get("/api/v1/user/margin", venue_credentials) do
      {:ok, account} =
        Tai.VenueAdapters.Bitmex.NormalizeAccount.build(margin, venue_id, credential_id)

      {:ok, [account]}
    else
      {:error, reason, _} -> {:error, reason}
    end
  end

  defp to_venue_credentials(credentials) do
    Tai.VenueAdapters.Bitmex.Credentials.from(credentials)
  end
end
