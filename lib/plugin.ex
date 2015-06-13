defmodule Plugin do
  alias Plugin
  import Ecto.Query

  def every_x(name, ms, channel, msg) do
    every_x(name, ms, fn ->
      ExIrc.Client.msg(:client, :privmsg, channel, msg)
    end)
  end
  def every_x(name, ms, cb) do
    q = from t in Database.Timer,
      where: t.cmd == ^name,
      select: t

    selection = Twitchbot.Repo.all q

    if selection == [] do
      t = %Database.Timer{cmd: name, interval: ms}
      t = Twitchbot.Repo.insert t

      cb.()

      Task.start_link(fn ->
        Stream.timer(ms) |> Enum.take(1) |> delete_timer(t)
      end)
    end
  end

  def delete_timer(_s, t) do
    Twitchbot.Repo.delete t
  end
end
