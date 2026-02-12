defmodule Tai.Events.BitmexStreamConnectionLimitDetails do
  @type t :: %Tai.Events.BitmexStreamConnectionLimitDetails{venue_id: atom, remaining: term}

  @enforce_keys [:venue_id, :remaining]
  defstruct [:venue_id, :remaining]

  @spec new(map) :: t
  def new(attrs), do: struct!(__MODULE__, attrs)
end
