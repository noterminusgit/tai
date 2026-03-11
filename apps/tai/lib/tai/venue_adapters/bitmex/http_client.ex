defmodule Tai.VenueAdapters.Bitmex.HTTPClient do
  @default_domain "www.bitmex.com"

  def domain, do: Application.get_env(:ex_bitmex, :domain, @default_domain)

  def get(path, credentials, params \\ %{}) do
    request(:get, path, credentials, "", params)
  end

  def post(path, credentials, body_params) do
    body = Jason.encode!(body_params)
    request(:post, path, credentials, body)
  end

  def put(path, credentials, body_params) do
    body = Jason.encode!(body_params)
    request(:put, path, credentials, body)
  end

  def delete(path, credentials, body_params) do
    body = Jason.encode!(body_params)
    request(:delete, path, credentials, body)
  end

  def get_unauthenticated(path, params \\ %{}) do
    url = "https://#{domain()}#{path}"
    url = if params == %{}, do: url, else: "#{url}?#{URI.encode_query(params)}"

    case Req.get(url, headers: [{"content-type", "application/json"}]) do
      {:ok, %Req.Response{status: status, body: body}} when status in 200..299 ->
        {:ok, body}

      {:ok, %Req.Response{body: body}} ->
        {:error, body}

      {:error, %Req.TransportError{reason: :timeout}} ->
        {:error, :timeout}

      {:error, %Req.TransportError{reason: :econnrefused}} ->
        {:error, :connect_timeout}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp request(verb, path, credentials, body, params \\ %{}) do
    url = "https://#{domain()}#{path}"
    expires = :os.system_time(:second) + 60
    verb_str = verb |> Atom.to_string() |> String.upcase()

    full_path = if params == %{}, do: path, else: "#{path}?#{URI.encode_query(params)}"
    signature_data = "#{verb_str}#{full_path}#{expires}#{body}"

    signature =
      :crypto.mac(:hmac, :sha256, credentials.api_secret, signature_data)
      |> Base.encode16(case: :lower)

    headers = [
      {"api-key", credentials.api_key},
      {"api-signature", signature},
      {"api-expires", "#{expires}"},
      {"content-type", "application/json"}
    ]

    url = if params == %{}, do: url, else: "#{url}?#{URI.encode_query(params)}"

    result =
      case verb do
        :get -> Req.get(url, headers: headers)
        :post -> Req.post(url, headers: headers, body: body)
        :put -> Req.put(url, headers: headers, body: body)
        :delete -> Req.request(method: :delete, url: url, headers: headers, body: body)
      end

    parse_result(result)
  end

  defp parse_result({:ok, %Req.Response{status: status, body: body, headers: headers}})
       when status in 200..299 do
    rate_limit = parse_rate_limit(headers)
    {:ok, body, rate_limit}
  end

  defp parse_result({:ok, %Req.Response{status: 429, headers: headers}}) do
    rate_limit = parse_rate_limit(headers)
    {:error, :rate_limited, rate_limit}
  end

  defp parse_result({:ok, %Req.Response{status: 503, headers: headers}}) do
    rate_limit = parse_rate_limit(headers)
    {:error, :overloaded, rate_limit}
  end

  defp parse_result({:ok, %Req.Response{body: %{"error" => %{"message" => msg}}, headers: headers}}) do
    rate_limit = parse_rate_limit(headers)

    cond do
      String.contains?(msg, "Nonce is not increasing") ->
        {:error, {:nonce_not_increasing, msg}, rate_limit}

      String.contains?(msg, "Account has insufficient") ->
        {:error, {:insufficient_balance, msg}, rate_limit}

      true ->
        {:error, msg, rate_limit}
    end
  end

  defp parse_result({:ok, %Req.Response{body: body, headers: headers}}) do
    rate_limit = parse_rate_limit(headers)
    {:error, body, rate_limit}
  end

  defp parse_result({:error, %Req.TransportError{reason: :timeout}}) do
    {:error, :timeout, nil}
  end

  defp parse_result({:error, %Req.TransportError{reason: :econnrefused}}) do
    {:error, :connect_timeout, nil}
  end

  defp parse_result({:error, %Req.TransportError{reason: :connect_timeout}}) do
    {:error, :connect_timeout, nil}
  end

  defp parse_result({:error, reason}) do
    {:error, reason, nil}
  end

  defp parse_rate_limit(headers) do
    %{
      remaining: get_header_int(headers, "x-ratelimit-remaining"),
      limit: get_header_int(headers, "x-ratelimit-limit"),
      reset: get_header_int(headers, "x-ratelimit-reset")
    }
  end

  defp get_header_int(headers, key) do
    case get_header(headers, key) do
      nil -> nil
      val -> String.to_integer(val)
    end
  end

  defp get_header(headers, key) when is_map(headers) do
    case Map.get(headers, key) do
      [value | _] -> value
      _ -> nil
    end
  end

  defp get_header(headers, key) when is_list(headers) do
    case List.keyfind(headers, key, 0) do
      {_, value} -> value
      nil -> nil
    end
  end
end
