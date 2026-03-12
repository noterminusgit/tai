defmodule Tai.Commander.Fleets do
  @spec get(keyword) :: [struct]
  def get(options) do
    Tai.Fleets.search(options)
  end
end
