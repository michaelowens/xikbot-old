defmodule Twitchbot.Spam do
  alias Twitchbot.Spam

  import Ecto.Query
  import Extension
  extends Plugin

  def start_link(client, whisper_client) do
    Agent.start_link(fn -> HashSet.new end, name: __MODULE__)
    update_cache()
    Agent.start_link(fn -> [] end, name: :longurl_services)
    update_shortened_urls()
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

  def update_shortened_urls() do
    # Get shorturl list from longurl
    # We do not continue to use this service as it is unreliable
    ircnick = Application.get_env(:twitchbot, :irc)[:nick]
    useragent = "#{ircnick}/1.0" # (Use username as recommended by longurl api)
    shortened_urls = HTTPoison.get!("http://api.longurl.org/v2/services?format=json", ["User-Agent": useragent]).body
                    |> Poison.decode!
                    |> Map.to_list()
                    |> Enum.map(fn(x) -> elem(x, 0) end)
    Agent.update(:longurl_services, fn list -> shortened_urls |> Enum.join("|") end)
    debug("Shortened URL supported services list updated (with longurl.org api)")
  end

  def handle_info({:received, msg, user, channel}, client) do
    channel = String.strip(channel)
    clean_channel = String.lstrip(channel, ?#)
    blacklist = Enum.join(get_cache(), "|")
    [cmd | tail] = String.split(msg, " ", trim: true)
    tail = Enum.join(tail, " ")
    cmd = String.downcase(cmd)

    # debug "Spam got message"
    shortened_urls = Agent.get(:longurl_services, fn list -> list end)
    found_shortened_urls = Regex.scan(~r/(#{shortened_urls})\/(\S+)/i, msg)

    if found_shortened_urls != [] do
      debug("Found shortened URL(s)")
      Enum.map(found_shortened_urls, fn (match) ->
        url = hd(match)
        {status, result, response_info} = UrlUnroller.unroll("http://" <> url)

        if status == :ok do
          if Regex.match?(~r/(#{blacklist})/i, result) do
            debug("Timing out #{user} for posting short link to blacklisted content")
            ExIrc.Client.msg(client, :privmsg, channel, ".timeout #{user} 600")
          end
        else
          debug("error finding expanded url: " <> url)
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
            if channel != user do
              whisper(channel, "#{user} has got your back! \"#{tail}\" has been blacklisted on your chat BloodTrail")
            end

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
    IO.puts IO.ANSI.yellow() <> "[SPAM] "<> msg <> IO.ANSI.reset()
  end
end
