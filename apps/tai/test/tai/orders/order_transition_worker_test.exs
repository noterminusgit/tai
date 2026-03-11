defmodule Tai.Orders.OrderTransitionWorkerTest do
  use Tai.TestSupport.DataCase, async: false

  alias Tai.Orders.OrderTransitionWorker

  describe ".process_name/1" do
    test "returns an atom based on index" do
      assert OrderTransitionWorker.process_name(0) == :"Elixir.Tai.Orders.OrderTransitionWorker_0"
      assert OrderTransitionWorker.process_name(1) == :"Elixir.Tai.Orders.OrderTransitionWorker_1"
    end
  end

  describe ".apply/2" do
    test "applies a skip transition to an enqueued order" do
      {:ok, order} = create_order(%{status: :enqueued})

      assert {:ok, updated_order} =
               OrderTransitionWorker.apply(order.client_id, %{__type__: :skip})

      assert updated_order.status == :skipped
    end

    test "returns error for invalid transition" do
      {:ok, order} = create_order(%{status: :canceled})

      assert {:error, {:invalid_status, :canceled, %Tai.Orders.Transitions.Skip{}}} =
               OrderTransitionWorker.apply(order.client_id, %{__type__: :skip})
    end

    test "returns error when order not found" do
      assert {:error, :order_not_found} =
               OrderTransitionWorker.apply(Ecto.UUID.generate(), %{__type__: :skip})
    end
  end
end
