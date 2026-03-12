defmodule Tai.Orders.OrderChangesetValidationTest do
  use Tai.TestSupport.DataCase, async: false
  alias Tai.Orders.Order

  @valid_attrs %{
    client_id: Ecto.UUID.generate(),
    venue: "venue_a",
    credential: "main",
    product_symbol: "btc_usd",
    venue_product_symbol: "BTC-USD",
    product_type: :spot,
    status: :enqueued,
    side: :buy,
    type: :limit,
    price: Decimal.new("100.5"),
    qty: Decimal.new("1.0"),
    leaves_qty: Decimal.new("1.0"),
    cumulative_qty: Decimal.new("0"),
    post_only: true,
    time_in_force: :gtc
  }

  describe "price validation" do
    test "rejects zero price" do
      changeset = Order.changeset(%Order{}, %{@valid_attrs | price: Decimal.new("0")})
      assert %{price: ["must be greater than 0"]} = errors_on(changeset)
    end

    test "rejects negative price" do
      changeset = Order.changeset(%Order{}, %{@valid_attrs | price: Decimal.new("-100")})
      assert %{price: ["must be greater than 0"]} = errors_on(changeset)
    end

    test "accepts positive price" do
      changeset = Order.changeset(%Order{}, @valid_attrs)
      assert changeset.valid?
    end
  end

  describe "qty validation" do
    test "rejects zero qty" do
      changeset = Order.changeset(%Order{}, %{@valid_attrs | qty: Decimal.new("0")})
      assert %{qty: ["must be greater than 0"]} = errors_on(changeset)
    end

    test "rejects negative qty" do
      changeset = Order.changeset(%Order{}, %{@valid_attrs | qty: Decimal.new("-1")})
      assert %{qty: ["must be greater than 0"]} = errors_on(changeset)
    end

    test "accepts positive qty" do
      changeset = Order.changeset(%Order{}, @valid_attrs)
      assert changeset.valid?
    end
  end

  describe "cumulative_qty validation" do
    test "rejects negative cumulative_qty" do
      changeset =
        Order.changeset(%Order{}, %{@valid_attrs | cumulative_qty: Decimal.new("-1")})

      assert %{cumulative_qty: ["must be greater than or equal to 0"]} = errors_on(changeset)
    end

    test "accepts zero cumulative_qty" do
      changeset =
        Order.changeset(%Order{}, %{@valid_attrs | cumulative_qty: Decimal.new("0")})

      assert changeset.valid?
    end
  end

  describe "leaves_qty validation" do
    test "rejects negative leaves_qty" do
      changeset = Order.changeset(%Order{}, %{@valid_attrs | leaves_qty: Decimal.new("-1")})
      assert %{leaves_qty: ["must be greater than or equal to 0"]} = errors_on(changeset)
    end

    test "accepts zero leaves_qty" do
      changeset = Order.changeset(%Order{}, %{@valid_attrs | leaves_qty: Decimal.new("0")})
      assert changeset.valid?
    end
  end
end
