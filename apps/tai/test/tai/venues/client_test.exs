defmodule Tai.Venues.ClientTest do
  use Tai.TestSupport.DataCase, async: false

  alias Tai.Venues.Client

  @venue_id :test_venue
  @credential_id :main

  defp setup_venue(adapter \\ Tai.VenueAdapters.Stub) do
    venue = %Tai.Venue{
      id: @venue_id,
      adapter: adapter,
      credentials: %{@credential_id => %{api_key: "key", api_secret: "secret"}},
      channels: [],
      products: "*",
      market_streams: "*",
      accounts: "*",
      quote_depth: 1,
      timeout: 10_000,
      start_on_boot: false,
      broadcast_change_set: false,
      opts: %{},
      stream_heartbeat_interval: 5_000,
      stream_heartbeat_timeout: 3_000
    }

    {:ok, _} = Tai.Venues.VenueStore.put(venue)
    venue
  end

  describe ".products/1" do
    test "delegates to the venue adapter" do
      venue = setup_venue()
      assert {:error, :not_implemented} = Client.products(venue)
    end
  end

  describe ".accounts/2" do
    test "delegates to the venue adapter with credentials" do
      venue = setup_venue()
      assert {:error, :not_implemented} = Client.accounts(venue, @credential_id)
    end
  end

  describe ".positions/2" do
    test "delegates to the venue adapter with credentials" do
      venue = setup_venue()
      assert {:error, :not_implemented} = Client.positions(venue, @credential_id)
    end
  end

  describe ".create_order/1" do
    test "delegates to the venue adapter" do
      setup_venue()
      {:ok, order} = create_order(%{status: :enqueued, venue: "test_venue", credential: "main"})
      assert {:error, :not_implemented} = Client.create_order(order)
    end
  end

  describe ".cancel_order/1" do
    test "delegates to the venue adapter" do
      setup_venue()
      {:ok, order} = create_order(%{status: :open, venue: "test_venue", credential: "main"})
      assert {:error, :not_implemented} = Client.cancel_order(order)
    end
  end
end
