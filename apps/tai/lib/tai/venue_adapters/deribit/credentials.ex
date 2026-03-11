defmodule Tai.VenueAdapters.Deribit.Credentials do
  @spec from(map) :: map
  def from(credentials) do
    Map.new(credentials)
  end
end
