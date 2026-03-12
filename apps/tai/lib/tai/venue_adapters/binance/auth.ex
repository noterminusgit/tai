defmodule Tai.VenueAdapters.Binance.Auth do
  @moduledoc """
  HMAC-SHA256 signed request helper for Binance API endpoints.
  """

  @base_url "https://api.binance.com"

  @spec signed_request(atom, String.t(), map, map) :: {:ok, term} | {:error, term}
  def signed_request(method, path, credentials, params \\ %{}) do
    url = @base_url <> path
    timestamp = System.system_time(:millisecond)
    params = Map.put(params, "timestamp", timestamp)
    query_string = URI.encode_query(params)

    signature =
      :crypto.mac(:hmac, :sha256, credentials.secret_key, query_string)
      |> Base.encode16(case: :lower)

    full_query = "#{query_string}&signature=#{signature}"
    full_url = "#{url}?#{full_query}"
    headers = [{"X-MBX-APIKEY", credentials.api_key}]

    case method do
      :get -> Req.get(full_url, headers: headers)
      :post -> Req.post(full_url, headers: headers)
      :delete -> Req.delete(full_url, headers: headers)
    end
  end
end
