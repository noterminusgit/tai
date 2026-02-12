defmodule Tai.Events.StreamMessageInvalidOrderClientIdTest do
  use ExUnit.Case, async: true

  test "struct has required fields" do
    {:ok, received_at, _} = DateTime.from_iso8601("2020-01-23T23:50:07.123+00:00")

    event =
      struct!(Tai.Events.StreamMessageInvalidOrderClientId,
        venue_id: :my_venue,
        client_id: "invalid-client-id-format",
        received_at: received_at
      )

    assert event.venue_id == :my_venue
    assert event.client_id == "invalid-client-id-format"
    assert event.received_at == received_at
  end

  test ".to_data/1 returns the struct as a map" do
    {:ok, received_at, _} = DateTime.from_iso8601("2020-01-23T23:50:07.123+00:00")

    event =
      struct!(Tai.Events.StreamMessageInvalidOrderClientId,
        venue_id: :my_venue,
        client_id: "invalid-client-id-format",
        received_at: received_at
      )

    assert %{} = json = TaiEvents.LogEvent.to_data(event)
    assert json.venue_id == :my_venue
    assert json.client_id == "invalid-client-id-format"
  end
end
