defmodule Tai.Venues.Adapters.AccountsErrorTest do
  use ExUnit.Case, async: false
  use ExVCR.Mock, adapter: ExVCR.Adapter.Finch

  setup_all do
    start_supervised!(Tai.TestSupport.Mocks.Server)
    :ok
  end

  setup do
    on_exit(fn ->
      :ok = Application.stop(:tai_events)
      :ok = Application.stop(:tai)
    end)

    # `:tai` may already be running from a previous test that didn't
    # stop it explicitly - ensure_all_started/1 is a no-op in that case,
    # so stop it first to guarantee a clean slate.
    Application.stop(:tai)
    {:ok, _} = Application.ensure_all_started(:tai)
    :ok
  end

  Tai.TestSupport.Helpers.test_venue_adapters_accounts_error()
  |> Enum.map(fn venue ->
    @venue venue
    @credential_id :error

    test "#{venue.id} returns an error with the reason" do
      use_cassette "venue_adapters/shared/accounts/#{@venue.id}/error" do
        assert {:error, reason} = Tai.Venues.Client.accounts(@venue, @credential_id)
        assert reason != nil
      end
    end
  end)
end
