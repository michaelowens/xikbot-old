defmodule RateLimiting do
  alias RateLimiting
  @moduledoc """
  A generic rate limiting module that utilises the ExRated library.
  You can store commands/IRC messages to buffer and send slowly as see fit, or
  just 'if rate not there just never execute the command' (aka ignore)
  """

  import ExRated

  def start_link() do
    Agent.start_link(fn -> HashDict.new end, name: __MODULE__)
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
    oldBuffer = Agent.get(__MODULE__, &HashDict.get(&1, %{name: name, ms: ms}))
    if oldBuffer == nil do # Set default because entry does not exist
      oldBuffer = []
    end
    Agent.update(__MODULE__, &HashDict.put(&1, %{name: name, ms: ms}, oldBuffer ++ [cb]))
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
    stuff_to_run = Agent.get(__MODULE__, fn dict -> dict end)
    dict_keys = stuff_to_run |> Dict.keys # Stuff with ms which were stored in states as keys in the dict

    if dict_keys |> length > 0 do # Theres something to do
      Enum.each(dict_keys, fn(key) -> 
        case ExRated.check_rate(key.name, key.ms, 1) do
        {:ok, _number} -> 
          [cmd | tail] = Dict.get(stuff_to_run, key)
          cmd.()
          if tail != [] do # Update with more commands if theres more
            Agent.update(__MODULE__, &HashDict.put(&1, %{name: key.name, ms: key.ms}, tail))
          else 
            # Or just trash the key
            Agent.update(__MODULE__, &HashDict.delete(&1, %{name: key.name, ms: key.ms}))
          end

        true -> nil
        end
      end)
      
    end

    # Use that timer thing to reinvoke itself every 15ms
    Stream.timer(15) |> Enum.take(1)
    rate_check_buffer()
  end

  defp debug(msg) do
    IO.puts IO.ANSI.yellow() <> msg <> IO.ANSI.reset()
  end
end
