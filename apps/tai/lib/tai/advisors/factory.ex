defmodule Tai.Advisors.Factory do
  @type fleet_config :: Tai.Fleets.FleetConfig.t()
  @type advisor_config :: Tai.Fleets.AdvisorConfig.t()

  @callback advisor_configs(fleet_config) :: [advisor_config]

  defmacro __using__(_) do
    quote location: :keep do
      @behaviour Tai.Advisors.Factory

      defp build_venue_product_keys(market_streams) do
        Tai.Products.product_symbols_by_venue()
        |> Juice.squeeze(market_streams)
        |> Enum.sort_by(fn {v, _symbols} -> v end)
        |> Enum.flat_map(fn {v, symbols} ->
          # Juice.squeeze/2 filters via MapSet internally, so it doesn't
          # preserve any particular symbol order - sort here rather than
          # relying on it.
          symbols
          |> Enum.sort()
          |> Enum.map(fn s -> {v, s} end)
        end)
      end
    end
  end
end
