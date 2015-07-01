defmodule Plugin do
  alias Plugin

  import ExRated

  def every_x(name, ms, channel, msg) do
    every_x(name, ms, fn ->
      ExIrc.Client.msg(:client, :privmsg, channel, msg)
    end)
  end
  def every_x(name, ms, cb) do
    if (ExRated.check_rate(name, ms, 1) |> elem(0)) == :ok do
      cb.()
    end
  end
end
