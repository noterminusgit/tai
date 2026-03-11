defmodule Tai.Orders.Transitions.VenueCreateError do
  @moduledoc """
  There was an error creating the order on the venue.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @behaviour Tai.Orders.Transition

  @type t :: %__MODULE__{}

  @primary_key false

  embedded_schema do
    field(:reason, EctoTerm.Embed)
  end

  @fields ~w[reason]a
  @spec changeset(t, map) :: Ecto.Changeset.t()
  def changeset(transition, params) do
    transition
    |> cast(params, @fields)
    |> validate_required(@fields)
  end

  @spec from :: [atom]
  def from, do: ~w[enqueued]a

  @spec attrs(t) :: keyword
  def attrs(_transition) do
    [
      leaves_qty: Decimal.new(0)
    ]
  end

  @spec status(atom) :: atom
  def status(_current) do
    :create_error
  end
end
