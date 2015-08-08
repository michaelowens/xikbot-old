defmodule Twitchbot.Spam do
  alias Twitchbot.Spam

  import Ecto.Query
  import Extension
  extends Plugin

  def start_link(client, whisper_client) do
    Agent.start_link(fn -> HashSet.new end, name: __MODULE__)
    update_cache()
    GenServer.start_link(__MODULE__, [client])
    GenServer.start_link(__MODULE__, [whisper_client])
  end

  @doc """
  Adds a pattern to the blacklist table
  """
  def blacklist(channel, user, pattern, time, is_perm_ban) do
    bl = %Database.Blacklist{channel: channel, added_by: user, pattern: pattern, time: time, is_perm_ban: is_perm_ban}
    Twitchbot.Repo.insert bl
    update_cache()
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
    clean_channel = String.lstrip(channel, ?#)
    blacklist = Enum.join(get_cache(), "|")
    [cmd | tail] = String.split(msg, " ", trim: true)
    tail = Enum.join(tail, " ")
    cmd = String.downcase(cmd)

    # debug "Spam got message"

    googl_urls = Regex.scan(~r/goo\.gl\/(\S+)/, msg)

    if googl_urls != [] do
      IO.puts "found urls"
      Enum.map(googl_urls, fn (match) ->
        url = hd(match)
        api_url = "https://www.googleapis.com/urlshortener/v1/url?shortUrl=http://" <> url <> "&key=" <> Application.get_env(:google_api, :key)
        response = HTTPoison.get!(api_url).body |> Poison.decode!

        if response["error"] do
          IO.puts "error finding expanded url: " <> url
        else
          if Regex.match?(~r/(#{blacklist})/i, response["longUrl"]) do
            IO.puts "Timing out #{user} for posting short link to blacklisted content"
            ExIrc.Client.msg(client, :privmsg, channel, ".timeout #{user} 600")
          end
        end
      end)
    end

    cond do
      Regex.match?(~r/(#{blacklist})/i, msg) ->
        ExIrc.Client.msg(client, :privmsg, channel, ".timeout #{user} 600")

      cmd == "!blacklist" and String.length(tail) > 0 and User.is_moderator(clean_channel, user) ->
        blacklist(channel, user, tail, 600, false)
        ExIrc.Client.msg(client, :privmsg, channel, "#{user}, I got you covered BloodTrail")

      true -> nil
    end

    {:noreply, client}
  end

  # Handle whispers (avoid mentioning the link in chat again)
  def handle_info({:unrecognized, "WHISPER", raw_msg}, client) do
    blacklist = Enum.join(get_cache(), "|")

    msg = raw_msg.args |> tl |> Enum.join(" ")
    user = raw_msg.nick

    # Standard cmd and tail split
    [cmd | tail] = String.split(msg, " ", trim: true)
    tail = Enum.join(tail, " ")

    cond do
      tail != "" ->
        # Split further
        [channel | tail] = String.split(tail, " ", trim: true)
        tail = Enum.join(tail, " ")

        cmd = String.downcase(cmd)
        channel = String.downcase(channel)

        cond do
          cmd == "blacklist" and String.length(tail) > 0 and User.is_moderator(channel, user) ->
            blacklist(channel, user, tail, 600, false)
            whisper(user, "I've got you covered! \"#{tail}\" has been blacklisted BloodTrail") # from #{channel}'s chat")
            whisper(channel, "#{user} has got your back! \"#{tail}\" has been blacklisted on your chat BloodTrail")

          true -> nil
        end

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
