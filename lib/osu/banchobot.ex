defmodule Banchobot do
  use Application

  defmodule State do
    defstruct host: "irc.freenode.net",
              port: 6667,
              pass: "",
              nick: "Banchobot",
              user: "Banchobot",
              name: "Banchobot",
              client: nil,
              channels: []
  end

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def init(_type) do
    import Supervisor.Spec, warn: false

    config = Application.get_env(:bancho, :irc) |> Enum.into %{}
    config = Map.merge(%State{}, config)

    {:ok, client} = ExIrc.start_client!

    Process.register(client, :bancho_client)

    children = [
      # Define workers and child supervisors to be supervised
      worker(BanchoConnectionHandler, [client]),
      # here's where we specify the channels to join:
      worker(BanchoLoginHandler, [client, []])
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Twitchbot.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def start_link() do
    GenServer.start_link(__MODULE__, [])
  end
end

defmodule BanchoConnectionHandler do
  def start_link(client) do
    GenServer.start_link(__MODULE__, [client])
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


defmodule BanchoLoginHandler do
  @moduledoc """
  This is an example event handler that listens for login events and then
  joins the appropriate channels. We actually need this because we can't
  join channels until we've waited for login to complete. We could just
  attempt to sleep until login is complete, but that's just hacky. This
  as an event handler is a far more elegant solution.
  """
  def start_link(client, channels) do
    GenServer.start_link(__MODULE__, [client, channels])
  end

  def init([client, channels]) do
    ExIrc.Client.add_handler client, self
    {:ok, {client, channels}}
  end

  def handle_info(:logged_in, state = {client, channels}) do
    debug "Logged in to bancho server"
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
