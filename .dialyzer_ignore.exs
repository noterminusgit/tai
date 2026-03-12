[
  # Venue adapter callback type mismatches - credentials type definition issue in Tai.Venues.Adapter
  ~r/venue_adapters\/binance.ex:\d+:callback_arg_type_mismatch/,
  ~r/venue_adapters\/gdax.ex:\d+:callback_arg_type_mismatch/,
  ~r/venue_adapters\/kraken.ex:\d+:callback_arg_type_mismatch/,
  # Bitmex HTTP client pattern match coverage - pre-existing
  ~r/venue_adapters\/bitmex\/http_client.ex:\d+:pattern_match_cov/
]
