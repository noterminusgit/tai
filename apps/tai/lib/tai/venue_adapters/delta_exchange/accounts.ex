defmodule Tai.VenueAdapters.DeltaExchange.Accounts do
  @spec accounts(atom, atom, map) :: {:ok, list}
  def accounts(_venue_id, _credential_id, _credentials) do
    {:ok, []}
  end
end
