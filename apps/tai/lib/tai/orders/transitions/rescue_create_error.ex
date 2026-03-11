defmodule Tai.Orders.Transitions.RescueCreateError do
  @moduledoc """
  While sending the create order request to the venue there was an uncaught
  error from the adapter, or an error processing it's response.
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
