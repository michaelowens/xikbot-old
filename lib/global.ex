defmodule Twitchbot.Global do
  alias Twitchbot.Global

  import Ecto.Query
  import Extension
  extends Plugin

  def start_link(client, whisper_client) do
    GenServer.start_link(__MODULE__, [client])
    GenServer.start_link(__MODULE__, [whisper_client])
  end

  def handle_info({:received, msg, user, channel}, client) do
    channel = String.strip(channel)
    clean_channel = String.lstrip(channel, ?#)
    [cmd | tail] = String.split(msg)
    cmd = String.downcase(cmd)

    # no global commands :^)

    {:noreply, client}
  end

  # Handle whispers (avoid mentioning the link in chat again)
  def handle_info({:unrecognized, "WHISPER", raw_msg}, client) do
    msg = raw_msg.args |> tl |> Enum.join(" ")
    user = raw_msg.nick

    # Standard cmd and tail split
    [cmd | tail] = String.split(msg, " ", trim: true)
    tail = Enum.join(tail, " ")

    cond do
      cmd == "say" and User.is_admin(user) ->
        if tail != "" do
          [channel | tail] = String.split(tail, " ", trim: true)
          tail = Enum.join(tail, " ")
          ExIrc.Client.msg(:client, :privmsg, channel, tail)
        end

      true -> nil
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
