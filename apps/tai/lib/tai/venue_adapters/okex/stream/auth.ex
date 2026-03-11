defmodule Tai.VenueAdapters.OkEx.Stream.Auth do
  @method "GET"
  @path "/users/self/verify"

  def args({
        _credential_id,
        %{api_key: api_key, api_secret: api_secret, api_passphrase: api_passphrase}
      }) do
    timestamp = DateTime.utc_now() |> DateTime.to_unix()
    message = "#{timestamp}" <> @method <> @path
    decoded_secret =
      case Base.decode64(api_secret) do
        {:ok, secret} -> secret
        :error -> raise ArgumentError, "invalid base64 in api_secret credential"
      end

    signed = :crypto.mac(:hmac, :sha256, decoded_secret, message) |> Base.encode64()

    [
      api_key,
      api_passphrase,
      timestamp,
      signed
    ]
  end
end
