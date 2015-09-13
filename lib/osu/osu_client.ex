defmodule Osu.Client do
  use Application

  defmodule State do
    defstruct host: "irc.ppy.sh",
              port: 6667,
              pass: "",
              nick: "OsuName_DontMultiAccountKids",
              client: nil,
              channels: []
  end

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def init([]) do
    import Supervisor.Spec, warn: false

    config = Application.get_env(:osu, :irc) |> Enum.into %{}
    config = Map.merge(%State{}, config)

    {:ok, osu_client} = ExIrc.Client.start_link

    Process.register(osu_client, :osu_client)

    children = [
      # Define workers and child supervisors to be supervised
      worker(OsuConnectionHandler, [osu_client, config]),
      # here's where we specify the channels to join:
      worker(OsuLoginHandler, [osu_client, []]),
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: OsuClient.Supervisor]
    Supervisor.start_link(children, opts)

    {:ok, osu_client}
  end

  def start_link() do
    GenServer.start_link(__MODULE__, [])
  end

  defp debug(msg) do
    IO.puts IO.ANSI.white() <> "[OSU_CLIENT] " <> IO.ANSI.yellow() <> msg <> IO.ANSI.reset()
  end
end

defmodule OsuLoginHandler do
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
    IO.puts IO.ANSI.white() <> "[OSU_CLIENT] " <> IO.ANSI.yellow() <> msg <> IO.ANSI.reset()
  end
end

defmodule OsuConnectionHandler do
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

  # Catch-all for messages you don't care about
  def handle_info(msg, state) do
    #debug "Received unknown messsage:"
    #IO.inspect msg
    {:noreply, state}
  end

  defp debug(msg) do
    IO.puts IO.ANSI.white() <> "[OSU_CLIENT] " <> IO.ANSI.yellow() <> msg <> IO.ANSI.reset()
  end
end
