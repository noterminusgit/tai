defmodule Tai.Settings do
  @moduledoc """
  Run time settings
  """

  use GenServer
  alias __MODULE__

  defmodule State do
    @moduledoc false

    @type t :: %__MODULE__{
            send_orders: boolean(),
            name: atom()
          }

    @enforce_keys ~w[send_orders name]a
    defstruct ~w[send_orders name]a
  end

  @type t :: %__MODULE__{
          send_orders: boolean()
        }

  @type id :: atom()

  @enforce_keys ~w[send_orders]a
  defstruct ~w[send_orders]a

  @default_id :default

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    config = Keyword.fetch!(opts, :config)
    id = Keyword.get(opts, :id, @default_id)
    name = process_name(id)
    state = %State{send_orders: config.send_orders, name: name}

    GenServer.start_link(__MODULE__, state, name: name)
  end

  @spec process_name(id()) :: atom()
  def process_name(id), do: :"#{__MODULE__}_#{id}"

  @spec disable_send_orders!(id()) :: :ok
  def disable_send_orders!(id \\ @default_id) do
    id
    |> process_name()
    |> GenServer.call({:set_send_orders, false})
  end

  @spec enable_send_orders!(id()) :: :ok
  def enable_send_orders!(id \\ @default_id) do
    id
    |> process_name()
    |> GenServer.call({:set_send_orders, true})
  end

  @spec send_orders?(id()) :: boolean()
  def send_orders?(id \\ @default_id) do
    [{:send_orders, send_orders}] =
      id
      |> process_name()
      |> :ets.lookup(:send_orders)

    send_orders
  end

  @spec all(id()) :: t()
  def all(id \\ @default_id) do
    %Settings{send_orders: send_orders?(id)}
  end

  @impl true
  def init(state) do
    {
      :ok,
      state,
      {:continue, :create_ets_table}
    }
  end

  @impl true
  def handle_continue(:create_ets_table, state) do
    create_ets_table(state.name)
    upsert_items(state)
    {:noreply, state}
  end

  @impl true
  def handle_call({:set_send_orders, val}, _from, state) do
    state.name
    |> :ets.insert({:send_orders, val})

    {:reply, :ok, state}
  end

  defp create_ets_table(name) do
    :ets.new(name, [:set, :protected, :named_table])
  end

  defp upsert_items(state) do
    state
    |> Map.to_list()
    |> Enum.filter(fn {k, _} -> k != :__struct__ end)
    |> Enum.each(fn item -> :ets.insert(state.name, item) end)
  end
end
