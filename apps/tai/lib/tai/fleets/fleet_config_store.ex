defmodule Tai.Fleets.FleetConfigStore do
  use Stored.Store

  @spec default_store_id :: atom
  def default_store_id, do: @default_id
end
