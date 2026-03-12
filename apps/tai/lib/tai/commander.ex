defmodule Tai.Commander do
  use GenServer

  @spec start_link(term) :: GenServer.on_start()
  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @spec accounts(keyword) :: term
  def accounts(options \\ []) do
    options |> to_dest() |> GenServer.call(:accounts)
  end

  @spec products(keyword) :: term
  def products(options \\ []) do
    options |> to_dest() |> GenServer.call(:products)
  end

  @spec fees(keyword) :: term
  def fees(options \\ []) do
    options |> to_dest() |> GenServer.call(:fees)
  end

  @spec markets(keyword) :: term
  def markets(options \\ []) do
    options |> to_dest() |> GenServer.call(:markets)
  end

  @spec orders(term, keyword) :: term
  def orders(query \\ nil, options \\ []) do
    options |> to_dest() |> GenServer.call({:orders, query, options})
  end

  @spec orders_count(term, keyword) :: term
  def orders_count(query \\ nil, options \\ []) do
    options |> to_dest() |> GenServer.call({:orders_count, query})
  end

  @spec get_order_by_client_id(term, keyword) :: term
  def get_order_by_client_id(client_id, options \\ []) do
    options |> to_dest() |> GenServer.call({:get_order_by_client_id, client_id})
  end

  @spec get_orders_by_client_ids(term, keyword) :: term
  def get_orders_by_client_ids(client_ids, options \\ []) do
    options |> to_dest() |> GenServer.call({:get_orders_by_client_ids, client_ids})
  end

  @spec order_transitions(term, term, keyword) :: term
  def order_transitions(client_id, query \\ nil, options \\ []) do
    options |> to_dest() |> GenServer.call({:order_transitions, client_id, query, options})
  end

  @spec order_transitions_count(term, term, keyword) :: term
  def order_transitions_count(client_id, query \\ nil, options \\ []) do
    options |> to_dest() |> GenServer.call({:order_transitions_count, client_id, query})
  end

  @spec failed_order_transitions(term, term, keyword) :: term
  def failed_order_transitions(client_id, query \\ nil, options \\ []) do
    options |> to_dest() |> GenServer.call({:failed_order_transitions, client_id, query, options})
  end

  @spec failed_order_transitions_count(term, term, keyword) :: term
  def failed_order_transitions_count(client_id, query \\ nil, options \\ []) do
    options |> to_dest() |> GenServer.call({:failed_order_transitions_count, client_id, query})
  end

  @spec delete_all_orders(keyword) :: term
  def delete_all_orders(options \\ []) do
    options |> to_dest() |> GenServer.call(:delete_all_orders, 60_000)
  end

  @spec positions(keyword) :: term
  def positions(options \\ []) do
    options |> to_dest() |> GenServer.call(:positions)
  end

  @spec venues(keyword) :: term
  def venues(options \\ []) do
    options |> to_dest() |> GenServer.call({:venues, options})
  end

  @spec start_venue(term, keyword) :: term
  def start_venue(venue_id, options \\ []) do
    options |> to_dest |> GenServer.call({:start_venue, venue_id, options})
  end

  @spec stop_venue(term, keyword) :: term
  def stop_venue(venue_id, options \\ []) do
    options |> to_dest |> GenServer.call({:stop_venue, venue_id, options})
  end

  @spec fleets(keyword) :: term
  def fleets(options \\ []) do
    options |> to_dest |> GenServer.call({:fleets, options})
  end

  @spec advisors(keyword) :: term
  def advisors(options \\ []) do
    options |> to_dest |> GenServer.call({:advisors, options})
  end

  @spec start_advisors(keyword) :: term
  def start_advisors(options \\ []) do
    options |> to_dest |> GenServer.call({:start_advisors, options})
  end

  @spec stop_advisors(keyword) :: term
  def stop_advisors(options \\ []) do
    options |> to_dest |> GenServer.call({:stop_advisors, options})
  end

  @spec settings(keyword) :: term
  def settings(options \\ []) do
    options |> to_dest |> GenServer.call(:settings)
  end

  @spec enable_send_orders(keyword) :: term
  def enable_send_orders(options \\ []) do
    options |> to_dest |> GenServer.call(:enable_send_orders)
  end

  @spec disable_send_orders(keyword) :: term
  def disable_send_orders(options \\ []) do
    options |> to_dest |> GenServer.call(:disable_send_orders)
  end

  def init(state) do
    {:ok, state}
  end

  def handle_call(:accounts, _from, state) do
    {:reply, Tai.Commander.Accounts.get(), state}
  end

  def handle_call(:products, _from, state) do
    {:reply, Tai.Commander.Products.get(), state}
  end

  def handle_call(:fees, _from, state) do
    {:reply, Tai.Commander.Fees.get(), state}
  end

  def handle_call(:markets, _from, state) do
    {:reply, Tai.Commander.Markets.get(), state}
  end

  def handle_call({:orders, query, options}, _from, state) do
    {:reply, Tai.Commander.Orders.get(query, options), state}
  end

  def handle_call({:orders_count, query}, _from, state) do
    {:reply, Tai.Commander.OrdersCount.get(query), state}
  end

  def handle_call({:get_order_by_client_id, client_id}, _from, state) do
    {:reply, Tai.Commander.GetOrderByClientId.get(client_id), state}
  end

  def handle_call({:get_orders_by_client_ids, client_ids}, _from, state) do
    {:reply, Tai.Commander.GetOrdersByClientIds.get(client_ids), state}
  end

  def handle_call({:order_transitions, client_id, query, options}, _from, state) do
    {:reply, Tai.Commander.OrderTransitions.get(client_id, query, options), state}
  end

  def handle_call({:order_transitions_count, client_id, query}, _from, state) do
    {:reply, Tai.Commander.OrderTransitionsCount.get(client_id, query), state}
  end

  def handle_call({:failed_order_transitions, client_id, query, options}, _from, state) do
    {:reply, Tai.Commander.FailedOrderTransitions.get(client_id, query, options), state}
  end

  def handle_call({:failed_order_transitions_count, client_id, query}, _from, state) do
    {:reply, Tai.Commander.FailedOrderTransitionsCount.get(client_id, query), state}
  end

  def handle_call(:delete_all_orders, _from, state) do
    {:reply, Tai.Commander.DeleteAllOrders.execute(), state}
  end

  def handle_call(:positions, _from, state) do
    {:reply, Tai.Commander.Positions.get(), state}
  end

  def handle_call({:venues, options}, _from, state) do
    {:reply, Tai.Commander.Venues.get(options), state}
  end

  def handle_call({:start_venue, venue_id, options}, _from, state) do
    {:reply, Tai.Commander.StartVenue.execute(venue_id, options), state}
  end

  def handle_call({:stop_venue, venue_id, store_id}, _from, state) do
    {:reply, Tai.Commander.StopVenue.execute(venue_id, store_id), state}
  end

  def handle_call({:fleets, options}, _from, state) do
    {:reply, Tai.Commander.Fleets.get(options), state}
  end

  def handle_call({:advisors, options}, _from, state) do
    {:reply, Tai.Commander.Advisors.get(options), state}
  end

  def handle_call({:start_advisors, options}, _from, state) do
    {:reply, Tai.Commander.StartAdvisors.execute(options), state}
  end

  def handle_call({:stop_advisors, options}, _from, state) do
    {:reply, Tai.Commander.StopAdvisors.execute(options), state}
  end

  def handle_call(:settings, _from, state) do
    {:reply, Tai.Commander.Settings.get(), state}
  end

  def handle_call(:enable_send_orders, _from, state) do
    {:reply, Tai.Commander.EnableSendOrders.execute(), state}
  end

  def handle_call(:disable_send_orders, _from, state) do
    {:reply, Tai.Commander.DisableSendOrders.execute(), state}
  end

  defp to_dest(options) do
    options
    |> Keyword.get(:node)
    |> case do
      nil -> __MODULE__
      node -> {__MODULE__, node}
    end
  end
end
