defmodule Tai.VenuesAdapters.Bitmex.ProductTest do
  use ExUnit.Case, async: false

  setup do
    on_exit(fn ->
      :ok = Application.stop(:tzdata)
    end)

    {:ok, _} = Application.ensure_all_started(:tzdata)
    :ok
  end

  describe ".build/2" do
    @base_attrs %{
      "symbol" => "XBTUSD",
      "underlying" => "XBT",
      "quoteCurrency" => "USD",
      "state" => "Open",
      "lotSize" => 1,
      "tickSize" => 0.5
    }

    test "returns a product struct from a venue instrument" do
      instrument = @base_attrs

      product = Tai.VenueAdapters.Bitmex.Product.build(instrument, :venue_a)
      assert product.venue_id == :venue_a
      assert product.symbol == :xbtusd
      assert product.venue_symbol == "XBTUSD"
      assert product.status == :trading
      assert product.price_increment == Decimal.new("0.5")
      assert product.min_price == Decimal.new("0.5")
      assert product.size_increment == Decimal.new(1)
      assert product.value == Decimal.new(1)
    end

    test "type is :future when there is an expiry" do
      instrument = Map.merge(@base_attrs, %{"expiry" => "2020-06-26T12:00:00.000Z"})

      product = Tai.VenueAdapters.Bitmex.Product.build(instrument, :venue_a)
      assert product.type == :future
    end

    test "type is :swap when there is no expiry" do
      instrument = Map.merge(@base_attrs, %{"expiry" => nil})

      product = Tai.VenueAdapters.Bitmex.Product.build(instrument, :venue_a)
      assert product.type == :swap
    end

    test "assigns maker/taker fee when present" do
      instrument = Map.merge(@base_attrs, %{"makerFee" => "-0.025", "takerFee" => "0.05"})

      product = Tai.VenueAdapters.Bitmex.Product.build(instrument, :venue_a)
      assert product.venue_id == :venue_a
      assert product.symbol == :xbtusd
      assert product.maker_fee == Decimal.new("-0.025")
      assert product.taker_fee == Decimal.new("0.05")
    end

    test "assigns max size when present" do
      instrument = Map.merge(@base_attrs, %{"maxOrderQty" => 100})

      product = Tai.VenueAdapters.Bitmex.Product.build(instrument, :venue_a)
      assert product.venue_id == :venue_a
      assert product.symbol == :xbtusd
      assert product.max_size == Decimal.new(100)
    end

    test "assigns max price when present" do
      instrument = Map.merge(@base_attrs, %{"maxPrice" => 100_000})

      product = Tai.VenueAdapters.Bitmex.Product.build(instrument, :venue_a)
      assert product.venue_id == :venue_a
      assert product.symbol == :xbtusd
      assert product.max_price == Decimal.new(100_000)
    end

    test "assigns listing & expiry when present" do
      instrument =
        Map.merge(@base_attrs, %{
          "listing" => "2019-12-13T06:00:00.000Z",
          "expiry" => "2020-03-27T12:00:00.000Z"
        })

      product = Tai.VenueAdapters.Bitmex.Product.build(instrument, :venue_a)
      assert product.venue_id == :venue_a
      assert product.symbol == :xbtusd
      assert %DateTime{} = product.listing
      assert %DateTime{} = product.expiry
    end

    test "returns nil when instrument lot_size is nil" do
      instrument = %{"lotSize" => nil}

      assert Tai.VenueAdapters.Bitmex.Product.build(instrument, :venue_a) == nil
    end
  end
end
