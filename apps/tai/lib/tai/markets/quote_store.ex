defmodule Tai.Markets.QuoteStore do
  use Stored.Store

  @spec after_put(term) :: term
  def after_put(market_quote) do
    Tai.Markets.publish_quote(market_quote)
  end
end
