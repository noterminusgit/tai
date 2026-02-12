defmodule Tai.Events.StreamChannelInvalidTest do
  use ExUnit.Case, async: true

  @base_attrs %{
    venue: :venue_a,
    name: :invalid_channel,
    available: [:channel_a, :channel_b]
  }

  test ".to_data/1 transforms available to a string" do
    event = struct!(Tai.Events.StreamChannelInvalid, @base_attrs)

    assert %{} = json = TaiEvents.LogEvent.to_data(event)
    assert json.venue == :venue_a
    assert json.name == :invalid_channel
    assert json.available == "[:channel_a, :channel_b]"
  end
end
