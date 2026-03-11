defmodule Tai.VenueAdapters.OkEx.Credentials do
  @spec from(map) :: map
  def from(credentials), do: Map.new(credentials)
end
