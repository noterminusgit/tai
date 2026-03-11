defmodule Tai.Orders.Transitions.PendAmend do
  @moduledoc """
  The order is going to be sent to the venue to be amended.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @behaviour Tai.Orders.Transition

  @type t :: %__MODULE__{}

  @primary_key false

  embedded_schema do
  end

  @spec changeset(t, map) :: Ecto.Changeset.t()
  def changeset(transition, params) do
    transition
    |> cast(params, [])
  end

  @spec from :: [atom]
  def from, do: ~w[open]a

  @spec attrs(t) :: keyword
  def attrs(_transition), do: []

  @spec status(atom) :: atom
  def status(_current) do
    :pending_amend
  end
end
