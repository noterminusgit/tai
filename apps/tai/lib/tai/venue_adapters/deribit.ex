defmodule Tai.VenueAdapters.Deribit do
  alias Tai.VenueAdapters.Deribit.{
    StreamSupervisor,
    Products,
    Accounts,
    Positions
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
  def create_order(_order, _credentials), do: {:error, :not_implemented}
  @impl true
  def amend_order(_order, _attrs, _credentials), do: {:error, :not_implemented}
  @impl true
  def amend_bulk_orders(_orders_with_attrs, _credentials), do: {:error, :not_supported}
  @impl true
  def cancel_order(_order, _credentials), do: {:error, :not_implemented}
end
