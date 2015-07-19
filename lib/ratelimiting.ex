defmodule RateLimiting do
  alias RateLimiting

  import ExRated

  def start_link() do
    Agent.start_link(fn -> [] end, name: __MODULE__)
    GenServer.start_link(__MODULE__, [])
  end

  def init([]) do
    spawn fn -> rate_check_for_messages() end
    {:ok, []}
  end

  def rate_send_message({name, ms, recipient, msg}, client) do
    debug("send msg")
    Agent.update(__MODULE__, fn list -> list = list ++ [{name, ms, recipient, msg, client}] end)
    debug("added to array")
  end

  def rate_check_for_messages() do
    to_send = Agent.get(__MODULE__, fn list -> list end)
    if to_send != [] do
      to_send_message = to_send |> hd
      name = to_send_message |> elem(0)
      ms = to_send_message |> elem(1)
      to = to_send_message |> elem(2)
      msg = to_send_message |> elem(3)
      client = to_send_message |> elem(4)
      case ExRated.check_rate(name, ms, 1) do
        {:ok, _number} ->
          ExIrc.Client.msg(client, :privmsg, to, msg)
          Agent.update(__MODULE__, fn list -> [tl(list)] end)

        _ -> nil
      end
    end

    # Use that timer thing to reinvoke itself every 10ms
    Stream.timer(10) |> Enum.take(1)
    rate_check_for_messages()
  end

  defp debug(msg) do
    IO.puts IO.ANSI.yellow() <> msg <> IO.ANSI.reset()
  end
end
