defmodule Tai.Orders.OrderCallbackStoreTest do
  use Tai.TestSupport.DataCase, async: false

  alias Tai.Orders.{OrderCallback, OrderCallbackStore}

  test "can put and find a callback" do
    callback = %OrderCallback{
      client_id: "test-client-id",
      callback: fn _prev, _curr -> :ok end
    }

    assert {:ok, _} = OrderCallbackStore.put(callback)
    assert {:ok, found} = OrderCallbackStore.find("test-client-id")
    assert found.client_id == "test-client-id"
  end

  test "returns error when callback not found" do
    assert {:error, :not_found} = OrderCallbackStore.find("nonexistent")
  end
end
