defmodule Tai.Orders.Transitions.VenueAmendError do
  @moduledoc """
  There was an error amending the order on the venue
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
  def from, do: ~w[pending_amend]a

  @spec attrs(t) :: keyword
  def attrs(_transition), do: []

  @spec status(atom) :: atom
  def status(_current) do
    :open
  end
end
