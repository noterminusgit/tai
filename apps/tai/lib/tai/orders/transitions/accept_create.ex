defmodule Tai.Orders.Transitions.AcceptCreate do
  @moduledoc """
  The create request has been received and accepted by the venue. The result
  of the created order will either be returned immediately in the response or
  received asynchronously on the connection stream.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @behaviour Tai.Orders.Transition

  @type t :: %__MODULE__{}

  @primary_key false

  embedded_schema do
    field(:venue_order_id, :string)
    field(:last_received_at, :utc_datetime_usec)
    field(:last_venue_timestamp, :utc_datetime_usec)
  end

  @spec changeset(t, map) :: Ecto.Changeset.t()
  def changeset(transition, params) do
    transition
    |> cast(params, [:venue_order_id, :last_received_at, :last_venue_timestamp])
    |> validate_required([:venue_order_id, :last_received_at])
  end

  @spec from :: [atom]
  def from, do: ~w[enqueued]a

  @spec attrs(t) :: keyword
  def attrs(transition) do
    [
      venue_order_id: transition.venue_order_id,
      last_received_at: transition.last_received_at,
      last_venue_timestamp: transition.last_venue_timestamp
    ]
  end

  @spec status(atom) :: atom
  def status(_current) do
    :create_accepted
  end
end
