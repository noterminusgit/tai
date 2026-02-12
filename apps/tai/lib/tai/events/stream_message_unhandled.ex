defmodule Tai.Events.StreamMessageUnhandled do
  alias __MODULE__

  @type t :: %StreamMessageUnhandled{
          venue_id: Tai.Venue.id(),
          msg: map,
          received_at: DateTime.t()
        }

  @enforce_keys ~w[venue_id msg received_at]a
  defstruct ~w[venue_id msg received_at]a

  @spec new(map) :: t
  def new(attrs), do: struct!(__MODULE__, attrs)
end
