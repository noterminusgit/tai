defmodule Tai.SymbolTest do
  use ExUnit.Case, async: true
  doctest Tai.Symbol

  describe ".downcase/1" do
    test "converts an atom to a downcase string" do
      assert Tai.Symbol.downcase(:FOO) == "foo"
    end

    test "converts an uppercase string to a downcase string" do
      assert Tai.Symbol.downcase("FOO") == "foo"
    end

    test "handles already lowercase atoms" do
      assert Tai.Symbol.downcase(:foo) == "foo"
    end

    test "handles already lowercase strings" do
      assert Tai.Symbol.downcase("foo") == "foo"
    end

    test "handles mixed case atoms" do
      assert Tai.Symbol.downcase(:BtC_UsDt) == "btc_usdt"
    end
  end

  describe ".downcase_all/1" do
    test "converts atoms to downcase strings" do
      assert Tai.Symbol.downcase_all([:FOO, :Bar]) == ["foo", "bar"]
    end

    test "converts uppercase strings to downcase strings" do
      assert Tai.Symbol.downcase_all(["FOO", "Bar"]) == ["foo", "bar"]
    end

    test "handles empty list" do
      assert Tai.Symbol.downcase_all([]) == []
    end

    test "handles mixed atoms and strings" do
      assert Tai.Symbol.downcase_all([:FOO, "BAR"]) == ["foo", "bar"]
    end
  end

  describe ".upcase/1" do
    test "converts an atom to an uppercase string" do
      assert Tai.Symbol.upcase(:foo) == "FOO"
    end

    test "converts a downcase string to an uppercase string" do
      assert Tai.Symbol.upcase("foo") == "FOO"
    end

    test "handles already uppercase atoms" do
      assert Tai.Symbol.upcase(:FOO) == "FOO"
    end

    test "handles already uppercase strings" do
      assert Tai.Symbol.upcase("FOO") == "FOO"
    end

    test "handles mixed case atoms" do
      assert Tai.Symbol.upcase(:BtC_UsDt) == "BTC_USDT"
    end
  end

  describe ".build/2" do
    test "returns a symbol for the base and quote asset separated by an underscore" do
      assert Tai.Symbol.build("btc", "usdt") == :btc_usdt
    end

    test "downcases the base and quote assets" do
      assert Tai.Symbol.build("BTC", "USDT") == :btc_usdt
    end

    test "handles mixed case assets" do
      assert Tai.Symbol.build("BtC", "uSdT") == :btc_usdt
    end
  end

  describe ".base_and_quote/1" do
    test "returns the base and quote asset from an atom in an ok tuple" do
      assert Tai.Symbol.base_and_quote(:btc_usdt) == {:ok, {:btc, :usdt}}
    end

    test "returns the base and quote asset from a string in an ok tuple" do
      assert Tai.Symbol.base_and_quote("btc_usdt") == {:ok, {:btc, :usdt}}
    end

    test "returns an error tuple when the symbol is an integer" do
      assert Tai.Symbol.base_and_quote(10) == {:error, :symbol_must_be_an_atom_or_string}
    end

    test "returns an error tuple when the symbol is a list" do
      assert Tai.Symbol.base_and_quote([:btc]) == {:error, :symbol_must_be_an_atom_or_string}
    end

    test "returns an error tuple when the symbol has more than 2 assets" do
      assert Tai.Symbol.base_and_quote(:btc_ltc_eth) ==
               {:error, :symbol_format_must_be_base_quote}
    end

    test "returns an error tuple when the symbol has only 1 asset" do
      assert Tai.Symbol.base_and_quote(:btc) ==
               {:error, :symbol_format_must_be_base_quote}
    end

    test "returns an error tuple for string with no underscore" do
      assert Tai.Symbol.base_and_quote("btcusdt") ==
               {:error, :symbol_format_must_be_base_quote}
    end
  end
end
