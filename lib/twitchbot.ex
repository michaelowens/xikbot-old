defmodule Twitchbot do
  use Application

  defmodule State do
    defstruct host: "irc.freenode.net",
              port: 6667,
              pass: "",
              nick: "Twitchbot",
              user: "Twitchbot",
              name: "Twitchbot",
              client: nil,
              channels: []
  end

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    config = Application.get_env(:Twitchbot, :irc) |> Enum.into %{}
    config = Map.merge(%State{}, config)

    Amnesia.start
    {:ok, client} = ExIrc.start_client!

    children = [
      # Define workers and child supervisors to be supervised
      # worker(Twitchbot.Worker, [arg1, arg2, arg3])
      worker(ExampleConnectionHandler, [client, config]),
      # here's where we specify the channels to join:
      worker(Twitchbot.ExampleLoginHandler, [client, config.channels]),
      worker(Twitchbot.EventsHandler, [client]),
      # worker(Twitchbot.YouTube, [client]),
      worker(Twitchbot.Spam, [client]),
      worker(Twitchbot.Kano, [client])
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Twitchbot.Supervisor]
    Supervisor.start_link(children, opts)
  end
end

defmodule ExampleConnectionHandler do
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
    ExIrc.Client.logon state.client, state.pass, state.nick, state.user, state.name
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
