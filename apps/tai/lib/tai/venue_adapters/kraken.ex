defmodule Tai.VenueAdapters.Kraken do
  alias Tai.VenueAdapters.Kraken.{
    StreamSupervisor,
    Products,
    Accounts,
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
  def positions(_venue_id, _credential_id, _credentials), do: {:error, :not_supported}
  @impl true
  defdelegate create_order(order, credentials), to: CreateOrder
  @impl true
  def amend_order(_venue_order_id, _attrs, _credentials), do: {:error, :not_supported}
  @impl true
  def amend_bulk_orders(_orders_with_attrs, _credentials), do: {:error, :not_supported}
  @impl true
  defdelegate cancel_order(order, credentials), to: CancelOrder
end
