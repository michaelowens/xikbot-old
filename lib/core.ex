defmodule Twitchbot.LoginHandler do
  alias Twitchbot.LoginHandler

  def start_link(client, channels) do
    GenServer.start_link(__MODULE__, [client, channels])
  end

  def init([client, channels]) do
    ExIrc.Client.add_handler client, self
    {:ok, {client, channels}}
  end

  def handle_info(:logged_in, state = {client, channels}) do
    debug "Logged in to twitch server"
    channels |> Enum.map(&ExIrc.Client.join client, &1)

    {:noreply, state}
  end

  # Catch-all for messages you don't care about
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  defp debug(msg) do
    IO.puts IO.ANSI.yellow() <> msg <> IO.ANSI.reset()
  end
end

defmodule Twitchbot.EventsHandler do
  alias Twitchbot.EventsHandler

  def start_link(client) do
    GenServer.start_link(__MODULE__, [client])
  end

  def init([client]) do
    ExIrc.Client.add_handler client, self
    {:ok, client}
  end

  def handle_info({:joined, channel}, client) do
    debug "Joined #{channel}"
    {:noreply, client}
  end

  def handle_info({:joined, channel, user}, client) do
    # ExIrc currently has a bug that doesn't remove the \r\n from the end
    # of the channel name with it sends along this kind of message
    # so we ensure any trailing or leading whitespace is explicitly removed
    channel = String.strip(channel)
    debug "#{user} joined #{channel}"
    # ExIrc.Client.msg(client, :privmsg, channel, "ohai #{user}")
    {:noreply, client}
  end

  def handle_info({:received, msg, user, channel}, client) do
    channel = String.strip(channel)
    [cmd | tail] = String.split(msg)

    debug "#{user} said in #{channel}: #{msg}"

    case cmd do
      "ping" -> ExIrc.Client.msg(client, :privmsg, channel, "@#{user} pong")
      # "!yt"  -> Twitchbot.YouTube.handle_yt({Enum.join(tail, " "), user, channel}, client)
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
end
