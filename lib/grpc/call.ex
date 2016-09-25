defmodule GRPC.Call do
  alias GRPC.Transport.Utils

  def unary(channel, path, message, opts) do
    headers = compose_headers(channel, path, opts)
    {:ok, data} = GRPC.Message.to_data(message, opts)
    :h2_client.sync_request(channel.pid, headers, data)
  end

  def compose_headers(channel, path, opts \\ []) do
    version = opts[:grpc_version] || GRPC.version
    [
      {":method", "POST"},
      {":scheme", channel.scheme},
      {":path", path},
      {":authority", channel.host},
      {"content-type", "application/grpc"},
      {"user-agent", "grpc-elixir/#{version}"},
      {"te", "trailers"}
    ]
    |> append_encoding(Keyword.get(opts, :send_encoding))
    |> append_timeout(Keyword.get(opts, :deadline))
    |> append_custom_metadata(Keyword.get(opts, :metadata))
    # TODO: grpc-accept-encoding, grpc-message-type
    # TODO: Authorization
  end

  defp append_encoding(headers, send_encoding) when is_binary(send_encoding) do
    headers ++ [{"grpc-encoding", send_encoding}]
  end
  defp append_encoding(headers, _), do: headers

  defp append_timeout(headers, deadline) when deadline != nil do
    headers ++ [{"grpc-timeout", Utils.encode_timeout(deadline)}]
  end
  defp append_timeout(headers, _), do: headers

  # TODO: Base64 encode Binary-Header for "*-bin" keys
  defp append_custom_metadata(headers, metadata) when is_map(metadata) and map_size(metadata) > 0 do
    new_headers = Enum.filter_map(metadata, fn({k, _v})-> !is_reserved_header(to_string(k)) end,
                                            fn({k, v}) -> normalize_custom_metadata({k, v}) end)
    headers ++ new_headers
  end
  defp append_custom_metadata(headers, _), do: headers

  defp normalize_custom_metadata({key, val}) when not is_binary(key) do
    normalize_custom_metadata({to_string(key), val})
  end
  defp normalize_custom_metadata({key, val}) when not is_binary(val) do
    normalize_custom_metadata({key, to_string(val)})
  end
  defp normalize_custom_metadata({key, val}) do
    val = if String.ends_with?(key, "-bin"), do: Base.encode64(val), else: val
    {String.downcase(to_string(key)), val}
  end

  defp is_reserved_header(":" <> _), do: true
  defp is_reserved_header("grpc-" <> _), do: true
  defp is_reserved_header("content-type"), do: true
  defp is_reserved_header("te"), do: true
  defp is_reserved_header(_), do: false
end