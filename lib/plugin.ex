defmodule Plugin do
  alias Plugin
  use XikBot.Database

  def everyX(name, ms, cb) do
    Amnesia.transaction do
      selection = Timer.where cmd == name

      if selection == nil do
        t = %Timer{cmd: name, interval: 0, last_run: 0}
          |> Timer.write

        cb.()

        Task.start_link(fn ->
          Stream.timer(ms) |> Enum.take(1) |> deleteTimer(t)
        end)
      end
    end
  end

  def deleteTimer(_s, t) do
    Amnesia.transaction do
      Timer.delete(t.id)
    end
  end
end
