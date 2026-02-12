defmodule Tai.SettingsTest do
  use Tai.TestSupport.DataCase, async: false

  @test_id __MODULE__

  describe ".process_name/1" do
    test "returns a namespaced atom with the given id" do
      assert Tai.Settings.process_name(:my_id) == :"Elixir.Tai.Settings_my_id"
    end

    test "returns a namespaced atom with the default id" do
      assert Tai.Settings.process_name(:default) == :"Elixir.Tai.Settings_default"
    end
  end

  describe ".start_link/1" do
    test "stores the settings in an ETS table" do
    config = Tai.Config.parse(send_orders: true)
    start_supervised!({Tai.Settings, [config: config, id: @test_id]})

    name = Tai.Settings.process_name(@test_id)
    assert :ets.lookup(name, :send_orders) == [{:send_orders, true}]
    end
  end

  describe ".send_orders?/1" do
    test "returns the value from the ETS table" do
    config = Tai.Config.parse(send_orders: true)
    start_supervised!({Tai.Settings, [config: config, id: @test_id]})

    assert Tai.Settings.send_orders?(@test_id) == true
    end

    test "returns false when send_orders is false" do
      config = Tai.Config.parse(send_orders: false)
      start_supervised!({Tai.Settings, [config: config, id: @test_id]})

      assert Tai.Settings.send_orders?(@test_id) == false
    end
  end

  describe ".enable_send_orders!/1" do
    test "updates the value in the ETS table to true" do
    config = Tai.Config.parse(send_orders: false)
    start_supervised!({Tai.Settings, [config: config, id: @test_id]})

    :ok = Tai.Settings.enable_send_orders!(@test_id)

    name = Tai.Settings.process_name(@test_id)
    assert :ets.lookup(name, :send_orders) == [{:send_orders, true}]
    end
  end

  describe ".disable_send_orders!/1" do
    test "updates the value in the ETS table to false" do
    config = Tai.Config.parse(send_orders: true)
    start_supervised!({Tai.Settings, [config: config, id: @test_id]})

    :ok = Tai.Settings.disable_send_orders!(@test_id)

    name = Tai.Settings.process_name(@test_id)
    assert :ets.lookup(name, :send_orders) == [{:send_orders, false}]
    end
  end

  describe ".all/1" do
    test "returns a struct with the values from the ETS table" do
    config = Tai.Config.parse(send_orders: true)
    start_supervised!({Tai.Settings, [config: config, id: @test_id]})

    settings = Tai.Settings.all(@test_id)

    assert settings.send_orders == true
    end

    test "returns a Settings struct type" do
      config = Tai.Config.parse(send_orders: false)
      start_supervised!({Tai.Settings, [config: config, id: @test_id]})

      settings = Tai.Settings.all(@test_id)

      assert %Tai.Settings{} = settings
      assert settings.send_orders == false
    end
  end
end
