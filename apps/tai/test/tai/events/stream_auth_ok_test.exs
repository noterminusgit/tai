defmodule Tai.Events.StreamAuthOkTest do
  use ExUnit.Case, async: true

  test "struct has required fields" do
    event = %Tai.Events.StreamAuthOk{
      venue: :my_venue,
      credential: :my_credential
    }

    assert event.venue == :my_venue
    assert event.credential == :my_credential
  end

  test ".to_data/1 returns the struct as a map" do
    event = %Tai.Events.StreamAuthOk{
      venue: :my_venue,
      credential: :my_credential
    }

    assert %{} = json = TaiEvents.LogEvent.to_data(event)
    assert json.venue == :my_venue
    assert json.credential == :my_credential
  end
end
