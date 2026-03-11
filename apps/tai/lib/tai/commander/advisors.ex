defmodule Tai.Commander.Advisors do
  @spec get(keyword) :: [struct]
  def get(options) do
    Tai.Advisors.search_instances(options)
  end
end
