defmodule Support.StartVenueAdapter do
  defmacro __using__(_) do
    quote do
      def stream_supervisor, do: Support.StartStreamSupervisor

      def products(_venue_id) do
        # A tiny delay so venue hydration takes long enough for a
        # Tai.Venues.Status.status/1 call right after start_supervised!
        # to reliably observe :starting before it flips to :running -
        # otherwise this can race depending on scheduler timing.
        Process.sleep(20)
        {:ok, []}
      end

      def accounts(_venue_id, _credential_id, _credentials) do
        {:ok, []}
      end

      def positions(_venue_id, _credential_id, _credentials) do
        {:ok, []}
      end

      def maker_taker_fees(_, _, _) do
        {:ok, nil}
      end

      defoverridable products: 1, accounts: 3, positions: 3, maker_taker_fees: 3
    end
  end
end
