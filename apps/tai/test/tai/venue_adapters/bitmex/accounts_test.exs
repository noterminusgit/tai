defmodule Tai.VenueAdapters.Bitmex.AccountsTest do
  use ExUnit.Case, async: false
  import Mock
  alias Tai.VenueAdapters.Bitmex

  @credentials %{api_key: "api_key", api_secret: "api_secret"}
  @rate_limit %{remaining: 100, limit: 300, reset: nil}

  test ".accounts normalizes the amount from satoshis to btc" do
    with_mock Bitmex.HTTPClient,
      get: fn "/api/v1/user/margin", _venue_credentials ->
        margin = %{"currency" => "XBt", "amount" => 133_558_082}
        {:ok, margin, @rate_limit}
      end do
      assert {:ok, accounts} = Bitmex.Accounts.accounts(:venue_a, :account_a, @credentials)

      assert btc_account = accounts |> hd()
      assert btc_account.locked == Decimal.new("1.33558082")
    end
  end
end
