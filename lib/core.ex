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
    debug "Logged in to server"
    channels |> Enum.map(&ExIrc.Client.join client, &1)

    {:noreply, state}
  end

  # Catch-all for messages you don't care about
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  defp debug(msg) do
    IO.puts IO.ANSI.yellow() <> "[TWITCH] " <> msg <> IO.ANSI.reset()
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

    # send notifs to slack
    slack_webhook = Application.get_env(:slack, :webhook)
    if slack_webhook != nil and String.length(slack_webhook) > 0 do
      slack_channel = Application.get_env(:slack, :channel)
      botnick = Application.get_env(:twitchbot, :irc)[:nick]

      if Regex.match?(~r/\b#{botnick}\b/i, msg) do
        clean_channel = channel |> String.lstrip ?#
        {:ok, response} = HTTPoison.get("https://api.twitch.tv/kraken/channels/#{clean_channel}")
        body = JSX.decode!(response.body, [{:labels, :atom}])

        logo = case body.logo do
          nil -> "http://static-cdn.jtvnw.net/jtv_user_pictures/xarth/404_user_150x150.png"
          _ -> body.logo
        end

        params = [
          channel: slack_channel,
          username: botnick,
          icon_emoji: ":raising_hand:",
          attachments: [
            [
              fallback: "*[#{channel}]* #{user}: #{msg}",
              author_name: "#{user} (#{channel})",
              author_link: "http://twitch.tv/#{user}",
              text: msg,
              thumb_url: logo
            ]
          ]
        ]
        HTTPoison.post(slack_webhook, JSX.encode! params)
      end
    end

    {:noreply, client}
  end

  # Catch-all for messages you don't care about
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  defp debug(msg) do
    IO.puts IO.ANSI.yellow() <> "[TWITCH] " <> msg <> IO.ANSI.reset()
  end
end
