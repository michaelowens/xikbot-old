defmodule RateLimiting do
  alias RateLimiting
  @moduledoc """
  A generic rate limiting module that utilises the ExRated library.
  You can store commands/IRC messages to buffer and send slowly as see fit, or
  just 'if rate not there just never execute the command' (aka ignore)
  """

  import ExRated

  def start_link() do
    Agent.start_link(fn -> [] end, name: __MODULE__)
    GenServer.start_link(__MODULE__, [])
  end

  def init([]) do
    spawn fn -> rate_check_buffer() end
    {:ok, []}
  end

  # Similar-ish logic to plugin.ex
  @doc """
  Places an ExIrc message into the 'buffer', ready to be checked against rate limiting and sent
  """
  def rate_buffer_message(name, ms, recipient, msg, client) do
    rate_buffer(name, ms, fn ->
      ExIrc.Client.msg(client, :privmsg, recipient, msg)
    end)
  end

  @doc """
  Adds a command into the 'buffer'
  """
  def rate_buffer(name, ms, cb) do
    Agent.update(__MODULE__, fn list -> list = list ++ [%{name: name, ms: ms, cmd: cb}] end)
  end

  @doc """
  Runs the command, if it is not ready to be run it will just be ignored
  """
  def rate_run(name, ms, cmd) do # from the plugin.ex
    case ExRated.check_rate(name, ms, 1) do
      {:ok, _number} -> cmd.()

      _ -> nil
    end
  end

  @doc """
  This module is invoked every 10ms to check for new commands to be run in the 'buffer'
  """
  def rate_check_buffer() do
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
    rate_check_buffer()
  end

  defp debug(msg) do
    IO.puts IO.ANSI.yellow() <> msg <> IO.ANSI.reset()
  end
end
