defmodule Tai.VenueAdapters.OkEx do
  alias Tai.VenueAdapters.OkEx.{
    StreamSupervisor,
    Products,
    Accounts,
    Positions,
    MakerTakerFees,
    CreateOrder,
    CancelOrder
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
  defdelegate positions(venue_id, credential_id, credentials), to: Positions
  @impl true
  defdelegate create_order(order, credentials), to: CreateOrder
  @impl true
  def amend_order(_order, _attrs, _credentials), do: {:error, :not_supported}
  @impl true
  def amend_bulk_orders(_orders_with_attrs, _credentials), do: {:error, :not_supported}
  @impl true
  defdelegate cancel_order(order, credentials), to: CancelOrder
end
