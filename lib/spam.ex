defmodule Twitchbot.Spam do
  alias Twitchbot.Spam

  import Ecto.Query
  import Extension
  extends Plugin

  def start_link(client) do
    Agent.start_link(fn -> HashSet.new end, name: __MODULE__)
    update_cache()
    GenServer.start_link(__MODULE__, [client])
  end

  @doc """
  Adds a pattern to the blacklist table
  """
  def blacklist(channel, pattern, time, is_perm_ban) do
    bl = %Database.Blacklist{channel: channel, pattern: pattern, time: time, is_perm_ban: is_perm_ban}
    Twitchbot.Repo.insert bl
  end

  def add_to_cache(pattern) do
    Agent.update(__MODULE__, &Set.put(&1, pattern))
  end

  def get_cache() do
    Agent.get(__MODULE__, &(&1))
  end

  def update_cache() do
    bl = Twitchbot.Repo.all from b in Database.Blacklist, select: b.pattern
    Agent.update(__MODULE__, fn _set -> Enum.into(bl, HashSet.new) end)
  end

  def handle_info({:received, msg, user, channel}, client) do
    channel = String.strip(channel)
    blacklist = Enum.join(get_cache(), "|")
    [cmd | tail] = String.split(msg)
    cmd = String.downcase(cmd)

    # debug "Spam got message"

    cond do
      Regex.match?(~r/(#{blacklist})/, msg) ->
        ExIrc.Client.msg(client, :privmsg, channel, ".timeout #{user} 600")

      cmd == "!blacklist" and User.is_moderator(channel, user) ->
        # add to blacklist
        IO.puts "no blacklist"

      true -> nil
    end

    {:noreply, client}
  end

  # Catch-all for messages you don't care about
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  def init([client]) do
    ExIrc.Client.add_handler client, self
    {:ok, client}
  end

  defp debug(msg) do
    IO.puts IO.ANSI.yellow() <> msg <> IO.ANSI.reset()
  end
end
