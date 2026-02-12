defmodule Tai.CommanderTest do
  use Tai.TestSupport.DataCase, async: false

  describe ".start_link/1" do
    test "starts the Commander GenServer" do
      assert Process.whereis(Tai.Commander) != nil
    end
  end

  describe ".settings/1" do
    test "returns the current settings" do
      settings = Tai.Commander.settings()

      assert %Tai.Settings{} = settings
    end
  end

  describe ".enable_send_orders/1" do
    test "enables send_orders setting" do
      Tai.Commander.disable_send_orders()
      assert Tai.Commander.settings().send_orders == false

      :ok = Tai.Commander.enable_send_orders()

      assert Tai.Commander.settings().send_orders == true
    end
  end

  describe ".disable_send_orders/1" do
    test "disables send_orders setting" do
      Tai.Commander.enable_send_orders()
      assert Tai.Commander.settings().send_orders == true

      :ok = Tai.Commander.disable_send_orders()

      assert Tai.Commander.settings().send_orders == false
    end
  end

  describe ".venues/1" do
    test "returns an empty list when no venues are configured" do
      venues = Tai.Commander.venues()

      assert venues == []
    end

    test "returns venues when they exist" do
      {:ok, _} =
        struct(
          Tai.Venue,
          id: :test_venue,
          credentials: %{},
          channels: [],
          quote_depth: 1,
          timeout: 1_000,
          start_on_boot: false
        )
        |> Tai.Venues.VenueStore.put()

      venues = Tai.Commander.venues()

      assert length(venues) >= 1
      assert Enum.any?(venues, fn v -> v.id == :test_venue end)
    end

    test "supports where filter option" do
      {:ok, _} =
        struct(
          Tai.Venue,
          id: :filter_test_venue_a,
          credentials: %{},
          channels: [],
          quote_depth: 1,
          timeout: 1_000,
          start_on_boot: false
        )
        |> Tai.Venues.VenueStore.put()

      {:ok, _} =
        struct(
          Tai.Venue,
          id: :filter_test_venue_b,
          credentials: %{},
          channels: [],
          quote_depth: 2,
          timeout: 1_000,
          start_on_boot: false
        )
        |> Tai.Venues.VenueStore.put()

      venues = Tai.Commander.venues(where: [id: :filter_test_venue_a])

      assert length(venues) == 1
      assert hd(venues).id == :filter_test_venue_a
    end
  end

  describe ".products/1" do
    test "returns an empty list when no products exist" do
      products = Tai.Commander.products()

      assert products == []
    end
  end

  describe ".accounts/1" do
    test "returns an empty list when no accounts exist" do
      accounts = Tai.Commander.accounts()

      assert accounts == []
    end
  end

  describe ".fees/1" do
    test "returns an empty list when no fees exist" do
      fees = Tai.Commander.fees()

      assert fees == []
    end
  end

  describe ".markets/1" do
    test "returns an empty list when no markets exist" do
      markets = Tai.Commander.markets()

      assert markets == []
    end
  end

  describe ".positions/1" do
    test "returns an empty list when no positions exist" do
      positions = Tai.Commander.positions()

      assert positions == []
    end
  end

  describe ".orders/2" do
    test "returns an empty list when no orders exist" do
      orders = Tai.Commander.orders()

      assert orders == []
    end
  end

  describe ".orders_count/2" do
    test "returns zero when no orders exist" do
      count = Tai.Commander.orders_count()

      assert count == 0
    end
  end

  describe ".fleets/1" do
    test "returns an empty list when no fleets are configured" do
      fleets = Tai.Commander.fleets()

      assert fleets == []
    end
  end

  describe ".advisors/1" do
    test "returns an empty list when no advisors are running" do
      advisors = Tai.Commander.advisors()

      assert advisors == []
    end
  end

  describe ".delete_all_orders/1" do
    test "returns ok with count of deleted orders" do
      result = Tai.Commander.delete_all_orders()

      assert {:ok, _count} = result
    end
  end

  describe "to_dest/1 (private)" do
    test "routes to local GenServer by default" do
      settings = Tai.Commander.settings()

      assert %Tai.Settings{} = settings
    end

    test "exits when trying to reach a nonexistent node" do
      assert catch_exit(Tai.Commander.settings(node: :nonexistent_node@localhost)) != nil
    end
  end
end
