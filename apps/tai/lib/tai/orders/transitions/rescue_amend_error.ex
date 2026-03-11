defmodule Tai.Orders.Transitions.RescueAmendError do
  @moduledoc """
  While sending the amend request for the order to the venue there was an
  uncaught error from the adapter, or an error processing it's response.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @behaviour Tai.Orders.Transition

  @type t :: %__MODULE__{}

  @primary_key false

  embedded_schema do
    field(:error, EctoTerm.Embed)
    field(:stacktrace, EctoTerm.Embed)
  end

  @fields ~w[error stacktrace]a
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
