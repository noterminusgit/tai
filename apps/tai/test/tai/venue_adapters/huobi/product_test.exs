defmodule Tai.VenueAdapters.Huobi.ProductTest do
  use ExUnit.Case, async: true
  alias Tai.VenueAdapters.Huobi.Product

  @base_attrs %{
    "contract_code" => "BTC_CW",
    "contract_type" => "this_week",
    "contract_status" => 1,
    "price_tick" => 0.01,
    "contract_size" => 100,
    "symbol" => "BTC",
    "create_date" => "20210101",
    "delivery_date" => "20210108"
  }

  describe ".build/2" do
    test "returns a product struct from a venue contract" do
      product = Product.build(@base_attrs, :venue_a)

      assert %Tai.Venues.Product{} = product
      assert product.venue_id == :venue_a
      assert product.symbol == :btc_cw
      assert product.venue_symbol == "BTC_CW"
      assert product.alias == "this_week"
      assert product.base == :btc
      assert product.quote == :usd
      assert product.type == :future
      assert product.is_inverse == true
      assert product.is_quanto == false
      assert product.value_side == :quote
    end

    test "parses price increment and contract size" do
      product = Product.build(@base_attrs, :venue_a)

      assert Decimal.equal?(product.price_increment, Decimal.new("0.01"))
      assert Decimal.equal?(product.value, Decimal.new("100"))
      assert Decimal.equal?(product.size_increment, Decimal.new("1"))
    end

    test "maps contract_status to status atom" do
      trading = Product.build(%{@base_attrs | "contract_status" => 1}, :venue_a)
      assert trading.status == :trading

      halt = Product.build(%{@base_attrs | "contract_status" => 3}, :venue_a)
      assert halt.status == :halt

      settled = Product.build(%{@base_attrs | "contract_status" => 8}, :venue_a)
      assert settled.status == :settled

      unknown = Product.build(%{@base_attrs | "contract_status" => 99}, :venue_a)
      assert unknown.status == :unknown
    end

    test "parses listing and expiry dates" do
      product = Product.build(@base_attrs, :venue_a)

      assert %DateTime{} = product.listing
      assert product.listing.year == 2021
      assert product.listing.month == 1
      assert product.listing.day == 1

      assert %DateTime{} = product.expiry
      assert product.expiry.year == 2021
      assert product.expiry.month == 1
      assert product.expiry.day == 8
      assert product.expiry.hour == 16
      assert product.expiry.minute == 0
    end
  end

  describe ".to_symbol/1" do
    test "converts instrument ID to lowercase atom" do
      assert Product.to_symbol("BTC-USD") == :btc_usd
      assert Product.to_symbol("ETH-USD") == :eth_usd
    end
  end
end
