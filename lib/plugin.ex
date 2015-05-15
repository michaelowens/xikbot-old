defmodule Plugin do
  alias Plugin
  use XikBot.Database

  def everyX(name, ms, cb) do
    IO.puts "--- everyX ---"

    Amnesia.transaction do
      selection = Timer.where cmd == name

      if selection == nil do
        t = %Timer{cmd: name, interval: 0, last_run: 0}
          |> Timer.write

        cb.()

        Stream.timer(ms) |> Enum.take(1) |> deleteTimer(t)
      end
    end
  end

  def deleteTimer(_s, t) do
    Amnesia.transaction do
      resp = Timer.delete(t.id)
      IO.puts resp
    end
  end
end
