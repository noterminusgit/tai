defmodule Tai.Orders.Transitions.Skip do
  @moduledoc """
  Bypass sending the order to the venue
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
  def from, do: ~w[enqueued]a

  def attrs(_) do
    [
      leaves_qty: Decimal.new(0)
    ]
  end

  @spec status(atom) :: atom
  def status(_current) do
    :skipped
  end
end
