defmodule Tai.Events.HydratePositions do
  @type t :: %Tai.Events.HydratePositions{
          venue_id: atom,
          total: non_neg_integer
        }

  @enforce_keys [:venue_id, :total]
  defstruct [:venue_id, :total]

  @spec new(map) :: t
  def new(attrs), do: struct!(__MODULE__, attrs)
end
