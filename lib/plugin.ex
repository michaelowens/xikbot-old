defmodule Plugin do
  alias Plugin
  import Ecto.Query

  def everyX(name, ms, channel, msg) do
    everyX(name, ms, fn ->
      ExIrc.Client.msg(:client, :privmsg, channel, msg)
    end)
  end
  def everyX(name, ms, cb) do
    q = from t in Database.Timer,
      where: t.cmd == ^name,
      select: t

    selection = Twitchbot.Repo.all q

    if selection == [] do
      t = %Database.Timer{cmd: name, interval: ms}
      t = Twitchbot.Repo.insert t

      cb.()

      Task.start_link(fn ->
        Stream.timer(ms) |> Enum.take(1) |> deleteTimer(t)
      end)
    end
  end

  def deleteTimer(_s, t) do
    Twitchbot.Repo.delete t
  end
end
