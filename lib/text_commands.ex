defmodule Twitchbot.TextCommands do
  alias Twitchbot.TextCommands

  import Ecto.Query
  import Extension
  extends Plugin

  def start_link(client) do
    Agent.start_link(fn -> HashDict.new end, name: __MODULE__) # Cache for matching the commands
    update_cache()
    GenServer.start_link(__MODULE__, [client])
  end

  def update_cache() do
    chan = Twitchbot.Repo.all from c in Database.TextCommands, select: [c.channel, c.command]
    chan  |> Enum.group_by(&List.first/1)
          |> Enum.each(fn(x) -> patterns = x |> elem(1) |> Enum.map(fn(y) -> y |> tl |> hd end)
                                Agent.update(__MODULE__, &HashDict.put(&1, elem(x, 0), patterns)) end)
  end

  def get_cache(channel) do
    Agent.get(__MODULE__, &HashDict.get(&1, channel))
  end

  def get_command_output(channel, command) do
    Twitchbot.Repo.all from c in Database.TextCommands,
                     where: c.channel == ^channel and c.command == ^command,
                    select: c.output
  end

  def add_command(channel, user, command, output) do
    selection = Twitchbot.Repo.all from c in Database.TextCommands,
                                  where: c.channel == ^channel and c.command == ^command,
                                 select: c

    if selection == [] do
      Twitchbot.Repo.insert %Database.TextCommands{channel: channel, added_by: user, command: command, output: output}
      ExIrc.Client.msg(:client, :privmsg, "#" <> channel, "Command '#{command}' has been added.")
      update_cache()
    else
      ExIrc.Client.msg(:client, :privmsg, "#" <> channel, "Command '#{command}' already exists. It has not been added to the system.")
    end
  end

  def delete_command(channel, command) do
    selection = Twitchbot.Repo.all from c in Database.TextCommands,
      where: c.channel == ^channel and c.command == ^command,
      select: c

    if selection == [] do
      ExIrc.Client.msg(:client, :privmsg, "#" <> channel, "Command '#{command}' does not exist. Nothing has been modified.")
    else
      Twitchbot.Repo.delete selection |> hd
      ExIrc.Client.msg(:client, :privmsg, "#" <> channel, "Command '#{command}' has been deleted.")
      update_cache()
    end
  end

  def edit_command(channel, user, command, output) do
    selection = Twitchbot.Repo.all from c in Database.TextCommands,
                                  where: c.channel == ^channel and c.command == ^command,
                                 select: c

    if selection == [] do
      ExIrc.Client.msg(:client, :privmsg, "#" <> channel, "Command '#{command}' does not exist. Nothing has been modified.")
    else
      [selection] = selection
      Twitchbot.Repo.update %{selection | added_by: user, output: output, updated_at: Ecto.DateTime.local()}
      ExIrc.Client.msg(:client, :privmsg, "#" <> channel, "Command '#{command}' has been updated.")
      update_cache()
    end
  end

  def add_and_get_counter(channel, command) do
    selection = Twitchbot.Repo.all from c in Database.TextCommands,
                                  where: c.channel == ^channel and c.command == ^command,
                                 select: c

    # Update counter with new value (+1)
    [selection] = selection
    count = (selection |> Map.get(:count)) + 1
    Twitchbot.Repo.update %{selection | count: count, updated_at: Ecto.DateTime.local()}

    # Return with value in string
    count |> to_string
  end

  def handle_info({:received, msg, user, channel}, client) do
    channel = String.strip(channel)
    clean_channel = String.lstrip(channel, ?#)
    [cmd | tail] = String.split(msg)
    cmd = String.downcase(cmd)
    channel_commands = get_cache(clean_channel)
    if channel_commands == nil do
      channel_commands = []
    end

    cond do
      Enum.member?(channel_commands, cmd) -> # Check if the 'cmd' is a known command
        if ExRated.check_rate("#{clean_channel}-#{cmd}", 2000, 1) |> elem(0) == :ok do
          out = get_command_output(clean_channel, cmd)
          if out != [] do
            # Add to and get the counter value for this command
            count = add_and_get_counter(clean_channel, cmd) # (a bit like set and get)

            # Do some string replacements for stuff like counters
            out = out |> to_string
            out = String.replace(out, "{user}", user) # Replaces with sender's name
            out = String.replace(out, "{count}", count) # Replaces with count

            ExIrc.Client.msg(client, :privmsg, channel, out)
          end
        end

      cmd == "!#{Application.get_env(:twitchbot, :irc)[:nick]}" and tail != [] ->
        [cmd | tail] = tail
        cmd = String.downcase(cmd)
        cond do
          cmd == "addcom" and tail != [] and User.is_moderator(clean_channel, user) ->
            [command | tail] = tail
            command = String.downcase(command)
            if tail != [] do
              add_command(clean_channel, user, command, Enum.join(tail, " "))
            end

          cmd == "delcom" and tail != [] and User.is_moderator(clean_channel, user) ->
            [command | tail] = tail
            command = String.downcase(command)
            delete_command(clean_channel, command)

          cmd == "editcom" and tail != [] and User.is_moderator(clean_channel, user) ->
            [command | tail] = tail
            command = String.downcase(command)
            if tail != [] do
              edit_command(clean_channel, user, command, Enum.join(tail, " "))
            end
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
    IO.puts IO.ANSI.yellow() <> "[TEXT_COMMAND] " <> msg <> IO.ANSI.reset()
  end

  def init([client]) do
    ExIrc.Client.add_handler client, self
    {:ok, client}
  end
end
