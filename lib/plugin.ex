defmodule Plugin do
  alias Plugin

  import ExRated

  def every_x(name, ms, channel, msg) do
    every_x(name, ms, fn ->
      ExIrc.Client.msg(:client, :privmsg, channel, msg)
    end)
  end
  def every_x(name, ms, cb) do
    case ExRated.check_rate(name, ms, 1) do
      {:ok, _number} -> cb.()

      _ -> nil
    end
  end

  def whisper(name, msg) do
    ExIrc.Client.msg(:whispers_client, :privmsg, "#jtv", ".w #{name} #{msg}")
  end
end
