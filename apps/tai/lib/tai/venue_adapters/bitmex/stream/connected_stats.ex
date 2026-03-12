defmodule Tai.VenueAdapters.Bitmex.Stream.ConnectedStats do
  @spec broadcast(map, atom, integer) :: :ok
  def broadcast(
        %{"bots" => bots, "users" => users},
        venue_id,
        received_at
      ) do
    TaiEvents.info(%Tai.Events.ConnectedStats{
      venue_id: venue_id,
      received_at: received_at,
      bots: bots,
      users: users
    })
  end
end
