defmodule Twitchbot do
  use Application

  defmodule State do
    defstruct host: "irc.twitch.tv",
              port: 6667,
              pass: "",
              nick: "Twitchbot",
              client: nil,
              channels: []
  end

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    config = Application.get_env(:twitchbot, :irc) |> Enum.into %{}
    config = Map.merge(%State{}, config)

    {:ok, client} = ExIrc.start_client!

    Process.register(client, :client)

    children = [
      # Define workers and child supervisors to be supervised
      # worker(Twitchbot.Worker, [arg1, arg2, arg3])
      worker(Twitchbot.Repo, []),
      worker(ConnectionHandler, [client, config]),
      # here's where we specify the channels to join:
      worker(Twitchbot.LoginHandler, [client, config.channels]),
      worker(Twitchbot.EventsHandler, [client]),
      # worker(Twitchbot.YouTube, [client]),
      worker(Twitch.Whispers, []),
      worker(Twitchbot.Global, [client, :whispers_client]),
      worker(Twitchbot.Spam, [client, :whispers_client]),
      worker(Twitchbot.Kano, [client])
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Twitchbot.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def say(message, channel \\ "#kano") do
    ExIrc.Client.msg(:client, :privmsg, channel, message)
  end
end

defmodule ConnectionHandler do
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
    ExIrc.Client.connect! state.client, state.host, state.port
    {:noreply, state}
  end

  # Catch-all for messages you don't care about
  def handle_info(msg, state) do
    # debug "Received unknown messsage:"
    # IO.inspect msg
    {:noreply, state}
  end

  defp debug(msg) do
    IO.puts IO.ANSI.yellow() <> msg <> IO.ANSI.reset()
  end
end
