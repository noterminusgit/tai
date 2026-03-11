defmodule Tai.VenueAdapters.Bitmex do
  alias Tai.VenueAdapters.Bitmex.{
    StreamSupervisor,
    Products,
    Accounts,
    Positions,
    CreateOrder,
    AmendOrder,
    AmendBulkOrders,
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
  def maker_taker_fees(_, _, _), do: {:ok, nil}
  @impl true
  defdelegate positions(venue_id, credential_id, credentials), to: Positions
  @impl true
  defdelegate create_order(order, credentials), to: CreateOrder
  @impl true
  defdelegate amend_order(order, attrs, credentials), to: AmendOrder
  @impl true
  defdelegate amend_bulk_orders(orders_with_attrs, credentials), to: AmendBulkOrders
  @impl true
  defdelegate cancel_order(order, credentials), to: CancelOrder
end
