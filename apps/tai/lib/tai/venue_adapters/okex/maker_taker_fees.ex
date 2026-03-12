defmodule Tai.VenueAdapters.OkEx.MakerTakerFees do
  @spec maker_taker_fees(atom, atom, map) :: {:ok, {Decimal.t(), Decimal.t()} | nil} | {:error, term}
  def maker_taker_fees(_venue_id, _credential_id, _credentials) do
    maker = Decimal.new("0.0002")
    taker = Decimal.new("0.0003")
    {:ok, {maker, taker}}
  end
end
