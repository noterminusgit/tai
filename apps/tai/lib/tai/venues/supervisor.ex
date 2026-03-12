defmodule Tai.Venues.Supervisor do
  use DynamicSupervisor

  @spec start_link(term) :: Supervisor.on_start()
  def start_link(_) do
    DynamicSupervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @spec start(Tai.Venue.t()) :: DynamicSupervisor.on_start_child()
  def start(venue) do
    DynamicSupervisor.start_child(__MODULE__, {Tai.Venues.Start, venue})
  end

  @spec stop(pid) :: :ok | {:error, :not_found}
  def stop(pid) when is_pid(pid) do
    DynamicSupervisor.terminate_child(__MODULE__, pid)
  end

  def init(_) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
