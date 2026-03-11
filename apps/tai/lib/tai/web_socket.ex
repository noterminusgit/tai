defmodule Tai.WebSocket do
  @spec send_msg(pid | atom, binary) :: :ok
  def send_msg(pid, msg), do: Fresh.send(pid, {:text, msg})

  @spec send_json_msg(pid | atom, map) :: :ok
  def send_json_msg(pid, msg), do: send_msg(pid, Jason.encode!(msg))
end
