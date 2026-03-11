defmodule Tai.VenueAdapters.DeltaExchange do
  alias Tai.VenueAdapters.DeltaExchange.{
    StreamSupervisor,
    Products,
    Accounts,
    MakerTakerFees,
    # Positions,
    # CreateOrder,
    # CancelOrder
  }

  @behaviour Tai.Venues.Adapter

  @impl true
  def stream_supervisor, do: StreamSupervisor
  @impl true
  defdelegate products(venue_id), to: Products
  @impl true
  defdelegate accounts(venue_id, credential_id, credentials), to: Accounts
  @impl true
  defdelegate maker_taker_fees(venue_id, credential_id, credentials), to: MakerTakerFees
  @impl true
  def positions(_venue_id, _credential_id, _credentials), do: {:error, :not_implemented}
  @impl true
  def create_order(_order, _credentials), do: {:error, :not_implemented}
  @impl true
  def amend_order(_order, _attrs, _credentials), do: {:error, :not_supported}
  @impl true
  def amend_bulk_orders(_orders_with_attrs, _credentials), do: {:error, :not_supported}
  @impl true
  def cancel_order(_order, _credentials), do: {:error, :not_implemented}
end
