defmodule Tai.Orders.OrderLifecycleTest do
  @moduledoc """
  Integration tests for order state machine lifecycle transitions.
  Tests full lifecycle flows through the OrderTransitionWorker using
  direct transition application (not venue adapters).
  """

  use Tai.TestSupport.DataCase, async: false

  alias Tai.Orders
  alias Tai.Orders.{Order, OrderRepo, OrderTransition, OrderTransitionWorker}

  @venue_order_id "df8e6bd0-a40a-42fb-8fea-b33ef4e34f14"
  @now DateTime.utc_now()
  @venue_ts DateTime.utc_now()

  describe "full fill lifecycle: enqueued → create_accepted → open → partial_fill → fill" do
    test "transitions through all states correctly" do
      {:ok, order} = create_order(%{status: :enqueued})
      client_id = order.client_id

      # enqueued → create_accepted
      assert {:ok, %Order{status: :create_accepted} = order} =
               OrderTransitionWorker.apply(client_id, %{
                 __type__: :accept_create,
                 venue_order_id: @venue_order_id,
                 last_received_at: @now,
                 last_venue_timestamp: @venue_ts
               })

      assert order.venue_order_id == @venue_order_id

      # create_accepted → open
      assert {:ok, %Order{status: :open} = order} =
               OrderTransitionWorker.apply(client_id, %{
                 __type__: :open,
                 venue_order_id: @venue_order_id,
                 cumulative_qty: Decimal.new(0),
                 leaves_qty: Decimal.new("2.1"),
                 last_received_at: @now,
                 last_venue_timestamp: @venue_ts
               })

      assert order.leaves_qty == Decimal.new("2.1")

      # open → open (partial fill is a self-transition for open status)
      assert {:ok, %Order{status: :open} = order} =
               OrderTransitionWorker.apply(client_id, %{
                 __type__: :partial_fill,
                 venue_order_id: @venue_order_id,
                 cumulative_qty: Decimal.new("1.0"),
                 leaves_qty: Decimal.new("1.1"),
                 last_received_at: @now,
                 last_venue_timestamp: @venue_ts
               })

      assert Decimal.equal?(order.cumulative_qty, Decimal.new("1.0"))
      assert Decimal.equal?(order.leaves_qty, Decimal.new("1.1"))

      # open → filled
      assert {:ok, %Order{status: :filled} = order} =
               OrderTransitionWorker.apply(client_id, %{
                 __type__: :fill,
                 venue_order_id: @venue_order_id,
                 cumulative_qty: Decimal.new("2.1"),
                 last_received_at: @now,
                 last_venue_timestamp: @venue_ts
               })

      assert order.cumulative_qty == Decimal.new("2.1")
      assert order.leaves_qty == Decimal.new(0)

      # Verify final persisted state
      saved = OrderRepo.get!(Order, client_id)
      assert saved.status == :filled
      assert saved.cumulative_qty == Decimal.new("2.1")
      assert saved.leaves_qty == Decimal.new(0)

      # Verify transition audit trail
      transitions = OrderRepo.all(OrderTransition)
      assert length(transitions) == 4
    end
  end

  describe "cancel lifecycle: open → pending_cancel → cancel_accepted → canceled" do
    test "transitions through all cancel states" do
      {:ok, order} = create_order(%{status: :open, venue_order_id: @venue_order_id})
      client_id = order.client_id

      # open → pending_cancel
      assert {:ok, %Order{status: :pending_cancel}} =
               OrderTransitionWorker.apply(client_id, %{__type__: :pend_cancel})

      # pending_cancel → cancel_accepted
      assert {:ok, %Order{status: :cancel_accepted}} =
               OrderTransitionWorker.apply(client_id, %{
                 __type__: :accept_cancel,
                 last_received_at: @now,
                 last_venue_timestamp: @venue_ts
               })

      # cancel_accepted → canceled
      assert {:ok, %Order{status: :canceled} = order} =
               OrderTransitionWorker.apply(client_id, %{
                 __type__: :cancel,
                 last_received_at: @now,
                 last_venue_timestamp: @venue_ts
               })

      assert order.leaves_qty == Decimal.new(0)

      saved = OrderRepo.get!(Order, client_id)
      assert saved.status == :canceled
    end

    test "direct cancel from open state" do
      {:ok, order} = create_order(%{status: :open, venue_order_id: @venue_order_id})

      # Some venues send cancel directly without pend_cancel/accept_cancel
      assert {:ok, %Order{status: :canceled}} =
               OrderTransitionWorker.apply(order.client_id, %{
                 __type__: :cancel,
                 last_received_at: @now,
                 last_venue_timestamp: @venue_ts
               })
    end
  end

  describe "amend lifecycle: open → pending_amend → accept_amend → amend → open" do
    test "transitions through all amend states" do
      {:ok, order} = create_order(%{status: :open, venue_order_id: @venue_order_id})
      client_id = order.client_id

      # open → pending_amend
      assert {:ok, %Order{status: :pending_amend}} =
               OrderTransitionWorker.apply(client_id, %{__type__: :pend_amend})

      # pending_amend → amend_accepted
      assert {:ok, %Order{status: :amend_accepted}} =
               OrderTransitionWorker.apply(client_id, %{
                 __type__: :accept_amend,
                 last_received_at: @now,
                 last_venue_timestamp: @venue_ts
               })

      # amend_accepted → open (via amend transition)
      assert {:ok, %Order{status: :open} = order} =
               OrderTransitionWorker.apply(client_id, %{
                 __type__: :amend,
                 price: Decimal.new("10500.0"),
                 leaves_qty: Decimal.new("3.0"),
                 last_received_at: @now,
                 last_venue_timestamp: @venue_ts
               })

      assert Decimal.equal?(order.price, Decimal.new("10500.0"))
      assert Decimal.equal?(order.leaves_qty, Decimal.new("3.0"))

      saved = OrderRepo.get!(Order, client_id)
      assert saved.status == :open
      assert Decimal.equal?(saved.price, Decimal.new("10500.0"))
    end
  end

  describe "error paths" do
    test "venue_create_error: enqueued → create_error" do
      {:ok, order} = create_order(%{status: :enqueued})

      assert {:ok, %Order{status: :create_error} = order} =
               OrderTransitionWorker.apply(order.client_id, %{
                 __type__: :venue_create_error,
                 reason: :insufficient_balance
               })

      assert order.leaves_qty == Decimal.new(0)
    end

    test "rescue_create_error: enqueued → create_error" do
      {:ok, order} = create_order(%{status: :enqueued})

      assert {:ok, %Order{status: :create_error} = order} =
               OrderTransitionWorker.apply(order.client_id, %{
                 __type__: :rescue_create_error,
                 error: %RuntimeError{message: "connection timeout"},
                 stacktrace: []
               })

      assert order.leaves_qty == Decimal.new(0)
    end

    test "invalid transition returns error" do
      {:ok, order} = create_order(%{status: :filled})

      assert {:error, {:invalid_status, :filled, %Orders.Transitions.Open{}}} =
               OrderTransitionWorker.apply(order.client_id, %{
                 __type__: :open,
                 venue_order_id: @venue_order_id,
                 cumulative_qty: Decimal.new(0),
                 leaves_qty: Decimal.new("1.0"),
                 last_received_at: @now
               })
    end

    test "transition on non-existent order returns error" do
      assert {:error, :order_not_found} =
               OrderTransitionWorker.apply(Ecto.UUID.generate(), %{
                 __type__: :accept_create,
                 venue_order_id: @venue_order_id,
                 last_received_at: @now
               })
    end
  end

  describe "fill during cancel" do
    test "partial fill while pending_cancel keeps pending_cancel status" do
      {:ok, order} =
        create_order(%{
          status: :pending_cancel,
          venue_order_id: @venue_order_id,
          cumulative_qty: Decimal.new(0),
          leaves_qty: Decimal.new("2.0")
        })

      assert {:ok, %Order{status: :pending_cancel} = order} =
               OrderTransitionWorker.apply(order.client_id, %{
                 __type__: :partial_fill,
                 venue_order_id: @venue_order_id,
                 cumulative_qty: Decimal.new("1.0"),
                 leaves_qty: Decimal.new("1.0"),
                 last_received_at: @now
               })

      assert Decimal.equal?(order.cumulative_qty, Decimal.new("1.0"))
    end

    test "fill while pending_cancel transitions to filled" do
      {:ok, order} =
        create_order(%{
          status: :pending_cancel,
          venue_order_id: @venue_order_id,
          cumulative_qty: Decimal.new(0),
          leaves_qty: Decimal.new("2.0")
        })

      assert {:ok, %Order{status: :filled}} =
               OrderTransitionWorker.apply(order.client_id, %{
                 __type__: :fill,
                 venue_order_id: @venue_order_id,
                 cumulative_qty: Decimal.new("2.0"),
                 last_received_at: @now
               })
    end
  end

  describe "transition from/0 status validation" do
    @transition_modules [
      Tai.Orders.Transitions.AcceptCreate,
      Tai.Orders.Transitions.AcceptCancel,
      Tai.Orders.Transitions.AcceptAmend,
      Tai.Orders.Transitions.Amend,
      Tai.Orders.Transitions.Cancel,
      Tai.Orders.Transitions.Expire,
      Tai.Orders.Transitions.Fill,
      Tai.Orders.Transitions.Open,
      Tai.Orders.Transitions.PartialFill,
      Tai.Orders.Transitions.PendAmend,
      Tai.Orders.Transitions.PendCancel,
      Tai.Orders.Transitions.Reject,
      Tai.Orders.Transitions.RescueAmendError,
      Tai.Orders.Transitions.RescueCancelError,
      Tai.Orders.Transitions.RescueCreateError,
      Tai.Orders.Transitions.Skip,
      Tai.Orders.Transitions.VenueAmendError,
      Tai.Orders.Transitions.VenueCancelError,
      Tai.Orders.Transitions.VenueCreateError
    ]

    @valid_statuses ~w[
      enqueued create_accepted create_error open filled
      pending_cancel cancel_accepted canceled
      pending_amend amend_accepted expired rejected skipped
    ]a

    for mod <- @transition_modules do
      test "#{mod} from/0 returns only valid Order status atoms" do
        from_statuses = unquote(mod).from()
        assert is_list(from_statuses)
        assert length(from_statuses) > 0

        for status <- from_statuses do
          assert status in @valid_statuses,
                 "#{unquote(mod)}.from/0 returned invalid status: #{inspect(status)}"
        end
      end
    end
  end
end
