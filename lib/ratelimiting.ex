defmodule RateLimiting do
  alias RateLimiting

  import ExRated

  def start_link() do
    Agent.start_link(fn -> [] end, name: __MODULE__)
    GenServer.start_link(__MODULE__, [])
  end

  def init([]) do
    spawn fn -> rate_check_for_stuff() end
    {:ok, []}
  end

  # Similar-ish logic to plugin.ex
  def rate_send_message(name, ms, recipient, msg, client) do
    rate_send(name, ms, fn ->
      ExIrc.Client.msg(client, :privmsg, recipient, msg)
    end)
  end

  def rate_send(name, ms, cb) do
    Agent.update(__MODULE__, fn list -> list = list ++ [%{name: name, ms: ms, cmd: cb}] end)
  end

  def rate_check_for_stuff() do
    stuff_to_run = Agent.get(__MODULE__, fn list -> list end)

    if stuff_to_run != [] do # Theres something to do
      thing_to_run = stuff_to_run |> hd
      name = thing_to_run.name
      ms = thing_to_run.ms
      cmd = thing_to_run.cmd

      case ExRated.check_rate(name, ms, 1) do
        {:ok, _number} -> 
          cmd.()
          Agent.update(__MODULE__, fn list -> tl(list) end)

        true -> nil
      end
    end

    # Use that timer thing to reinvoke itself every 10ms
    Stream.timer(10) |> Enum.take(1)
    rate_check_for_stuff()
  end

  defp debug(msg) do
    IO.puts IO.ANSI.yellow() <> msg <> IO.ANSI.reset()
  end
end
