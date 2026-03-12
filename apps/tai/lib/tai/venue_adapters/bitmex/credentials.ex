defmodule Tai.VenueAdapters.Bitmex.Credentials do
  @spec from(map) :: map
  def from(%{api_key: _, api_secret: _} = attrs) do
    %{api_key: attrs.api_key, api_secret: attrs.api_secret}
  end
end
