# Client module to connect to Twitch Group Chat server
# This is required for whispers as whispers must be sent through this server

defmodule Twitch.Whispers do
  use Application

  defmodule State do
    defstruct host: "199.9.253.119",
              port: 443,
              pass: "",
              nick: "Twitchbot",
              client: nil,
              channels: []
  end

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def init([]) do
    import Supervisor.Spec, warn: false

    config = Application.get_env(:twitchbot, :irc, [:nick, :pass]) |> Enum.into %{}
    config = Map.merge(%State{}, config)

    {:ok, client} = ExIrc.Client.start_link

    Process.register(client, :whispers_client)

    children = [
      # Define workers and child supervisors to be supervised
      worker(WhispersConnectionHandler, [client, config]),
      # here's where we specify the channels to join:
      worker(WhispersLoginHandler, [client, []]),
      worker(WhispersEventsHandler, [client])
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Twitch.Whispers.Supervisor]
    Supervisor.start_link(children, opts)

    {:ok, client}
  end

  def start_link() do
    GenServer.start_link(__MODULE__, [])
  end

  defp debug(msg) do
    IO.puts IO.ANSI.yellow() <> "[WHISPERS] " <> msg <> IO.ANSI.reset()
  end
end

defmodule WhispersLoginHandler do
  def start_link(client, channels) do
    GenServer.start_link(__MODULE__, [client, channels])
  end

  def init([client, channels]) do
    ExIrc.Client.add_handler client, self
    {:ok, {client, channels}}
  end

  def handle_info(:logged_in, state = {client, channels}) do
    debug "Logged in to server"

    # CAP requirements for whispers (sends the CAP REQ with raw irc)
    ExIrc.Client.cmd(client, "CAP REQ :twitch.tv/commands")

    {:noreply, state}
  end

  # Catch-all for messages you don't care about
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  defp debug(msg) do
    IO.puts IO.ANSI.yellow() <> "[WHISPERS] " <> msg <> IO.ANSI.reset()
  end
end

defmodule WhispersConnectionHandler do
  def start_link(client, state) do
    GenServer.start_link(__MODULE__, [%{state | client: client}])
  end

  def init([state]) do
    ExIrc.Client.add_handler state.client, self
    ExIrc.Client.connect! state.client, state.host, state.port
    {:ok, state}
  end

  def handle_info({:connected, server, port}, state) do
    debug "Connected to #{server}:#{port}"
    ExIrc.Client.logon state.client, state.pass, state.nick, state.nick, state.nick
    {:noreply, state}
  end

  def handle_info(:disconnected, state) do
    debug "Disconnected from #{state.host}:#{state.port}"

    # send notice to slack
    slack_webhook = Application.get_env(:slack, :webhook)
    if slack_webhook != nil and String.length(slack_webhook) > 0 do
      params = [
        channel: Application.get_env(:slack, :notices_channel),
        username: Application.get_env(:twitchbot, :irc)[:nick],
        icon_emoji: ":warning:",
        text: "Whisper client disconnected!"
      ]
      HTTPoison.post(slack_webhook, JSX.encode! params)
    end

    ExIrc.Client.connect! state.client, state.host, state.port
    {:noreply, state}
  end

  # Catch-all for messages you don't care about
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  defp debug(msg) do
    IO.puts IO.ANSI.yellow() <> "[WHISPERS] " <> msg <> IO.ANSI.reset()
  end
end

defmodule WhispersEventsHandler do
  def start_link(client) do
    GenServer.start_link(__MODULE__, [client])
  end

  def init([client]) do
    ExIrc.Client.add_handler client, self
    {:ok, client}
  end

  def handle_info({:unrecognized, "WHISPER", msg}, state) do
    user = msg.nick
    [cmd | tail] = msg.args |> tl |> Enum.join(" ") |> String.split

    debug "#{msg.nick} whispered: #{tl(msg.args) |> Enum.join(" ")}"

    case cmd do
      "ping" -> ExIrc.Client.msg(:whispers_client, :privmsg, "#jtv", ".w #{user} pong")
            _      -> nil
    end
    {:noreply, state}
  end

  # Catch-all for messages you don't care about
  def handle_info(msg, state) do
    {:noreply, state}
  end

  defp debug(msg) do
    IO.puts IO.ANSI.yellow() <> "[WHISPERS] " <> msg <> IO.ANSI.reset()
  end
end
