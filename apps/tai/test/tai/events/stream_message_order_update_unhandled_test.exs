defmodule Tai.Events.StreamMessageOrderUpdateUnhandledTest do
  use ExUnit.Case, async: true

  test "struct has required fields" do
    {:ok, received_at, _} = DateTime.from_iso8601("2020-01-23T23:50:07.123+00:00")

    event =
      struct!(Tai.Events.StreamMessageOrderUpdateUnhandled,
        venue_id: :my_venue,
        msg: %{"type" => "order_update", "status" => "unknown"},
        received_at: received_at
      )

    assert event.venue_id == :my_venue
    assert event.msg == %{"type" => "order_update", "status" => "unknown"}
    assert event.received_at == received_at
  end

  test ".to_data/1 returns the struct as a map" do
    {:ok, received_at, _} = DateTime.from_iso8601("2020-01-23T23:50:07.123+00:00")

    event =
      struct!(Tai.Events.StreamMessageOrderUpdateUnhandled,
        venue_id: :my_venue,
        msg: %{"type" => "order_update", "status" => "unknown"},
        received_at: received_at
      )

    assert %{} = json = TaiEvents.LogEvent.to_data(event)
    assert json.venue_id == :my_venue
    assert json.msg == %{"type" => "order_update", "status" => "unknown"}
  end
end
