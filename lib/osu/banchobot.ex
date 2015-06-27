defmodule Banchobot do
  use Application

  defmodule State do
    defstruct host: "irc.freenode.net",
              port: 6667,
              pass: "",
              nick: "Banchobot",
              user: "Banchobot",
              name: "Banchobot",
              bancho_client: nil,
              channels: []
  end

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def init([]) do
    import Supervisor.Spec, warn: false

    config = Application.get_env(:bancho, :irc) |> Enum.into %{}
    config = Map.merge(%State{}, config)

    {:ok, bancho_client} = ExIrc.Client.start_link

    Process.register(bancho_client, :bancho_client)

    # children = [
    #   # Define workers and child supervisors to be supervised
    #   worker(BanchoConnectionHandler, [bancho_client, config]),
    #   # here's where we specify the channels to join:
    #   worker(BanchoLoginHandler, [bancho_client, []])
    # ]
    #
    # # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # # for other strategies and supported options
    # opts = [strategy: :one_for_one, name: Banchobot.Supervisor]
    # Supervisor.start_link(children, opts)

    {:ok, handler} = ExampleHandler.start_link(nil)
    ExIrc.Client.add_handler(bancho_client, handler)
    ExIrc.Client.connect!(bancho_client, config.host, config.port)
    ExIrc.Client.logon(bancho_client, config.pass, config.nick, config.user, config.name)

    {:ok, bancho_client}
  end

  def start_link() do
    GenServer.start_link(__MODULE__, [])
  end
end
