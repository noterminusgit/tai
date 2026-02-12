defmodule Tai.Events.PositionUpdate do
  @type t :: %Tai.Events.PositionUpdate{
          venue_id: atom,
          symbol: atom,
          received_at: DateTime.t(),
          data: map
        }

  @enforce_keys [
    :venue_id,
    :symbol,
    :received_at,
    :data
  ]
  defstruct [
    :venue_id,
    :symbol,
    :received_at,
    :data
  ]

  @spec new(map) :: t
  def new(attrs), do: struct!(__MODULE__, attrs)
end
