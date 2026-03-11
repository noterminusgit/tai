defmodule Tai.VenueAdapters.DeltaExchange.MakerTakerFees do
  @spec maker_taker_fees(atom, atom, map) :: {:ok, {Decimal.t(), Decimal.t()} | nil} | {:error, term}
  def maker_taker_fees(_venue_id, _credential_id, _credentials) do
    {:ok, nil}
  end
end
