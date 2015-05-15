defmodule Twitchbot.Kano do
  alias Twitchbot.Kano

  import Extension
  extends Plugin

  @bucket nil

  def start_link(client) do
    GenServer.start_link(__MODULE__, [client])
  end

  def handle_info({:received, msg, user, channel}, client) do
    channel = String.strip(channel)
    [cmd | tail] = String.split(msg)

    case cmd do
      # Advanced commands
      "!ilovedicks" -> handle_info({:nothing, user, channel}, client)

      # Simple replies
      "!downtime"   -> everyX(cmd, 5000, fn ->
        ExIrc.Client.msg(client, :privmsg, channel, "oi #{user}, u rly think ur funny m8?")
      end)
      _      -> nil
    end

    {:noreply, client}
  end

  # Catch-all for messages you don't care about
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  defp debug(msg) do
    IO.puts IO.ANSI.yellow() <> msg <> IO.ANSI.reset()
  end

  def init([client]) do
    ExIrc.Client.add_handler client, self
    {:ok, client}
  end
end
