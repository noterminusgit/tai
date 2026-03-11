defmodule Tai.VenueAdapters.OkEx.AccountsTest do
  use ExUnit.Case, async: false
  import Mock
  alias Tai.VenueAdapters.OkEx

  @credentials %{api_key: "api_key", api_secret: "YXBpX3NlY3JldA=="}

  test ".accounts hydrates spot, swap & futures accounts" do
    with_mocks [
      {
        OkEx.Accounts,
        [:passthrough],
        fetch_futures: fn _venue_id, _credential_id, _venue_credentials ->
          account = %Tai.Venues.Account{
            venue_id: :venue_a,
            credential_id: :credential_a,
            asset: :btc,
            type: "futures",
            equity: Decimal.new("1.1"),
            free: Decimal.new(0),
            locked: Decimal.new("1.1")
          }

          {:ok, [account]}
        end,
        fetch_swap: fn _venue_id, _credential_id, _venue_credentials ->
          account = %Tai.Venues.Account{
            venue_id: :venue_a,
            credential_id: :credential_a,
            asset: :btc,
            type: "swap",
            equity: Decimal.new("1.2"),
            free: Decimal.new(0),
            locked: Decimal.new("1.2")
          }

          {:ok, [account]}
        end,
        fetch_spot: fn _venue_id, _credential_id, _venue_credentials ->
          account = %Tai.Venues.Account{
            venue_id: :venue_a,
            credential_id: :credential_a,
            asset: :btc,
            type: "spot",
            equity: Decimal.new("1.3"),
            free: Decimal.new("1.0"),
            locked: Decimal.new("0.3")
          }

          {:ok, [account]}
        end
      }
    ] do
      assert {:ok, accounts} = OkEx.Accounts.accounts(:venue_a, :credential_a, @credentials)

      assert Enum.count(accounts) == 3

      assert %Tai.Venues.Account{} = futures_account = Enum.at(accounts, 0)
      assert futures_account.locked == Decimal.new("1.1")
      assert futures_account.type == "futures"

      assert %Tai.Venues.Account{} = swap_account = Enum.at(accounts, 1)
      assert swap_account.locked == Decimal.new("1.2")
      assert swap_account.asset == :btc
      assert swap_account.type == "swap"

      assert %Tai.Venues.Account{} = spot_account = Enum.at(accounts, 2)
      assert spot_account.locked == Decimal.new("0.3")
      assert spot_account.free == Decimal.new("1.0")
      assert spot_account.asset == :btc
      assert spot_account.type == "spot"
    end
  end
end
