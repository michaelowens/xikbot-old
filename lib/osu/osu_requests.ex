# Module for handling osu! requests to xikbot in elixir
# by n2468txd
# http://n2468txd.github.io/
#
# In the config this module is activated for whatever channel which has an associated osu username
# If they don't then they are just ignored.

defmodule Twitchbot.OsuRequests do
  alias Twitchbot.OsuRequests

  import HTTPoison

  def start_link(client) do
    GenServer.start_link(__MODULE__, [client])
  end

  def init([client]) do
    ExIrc.Client.add_handler client, self
    {:ok, client}
  end

  def handle_info({:joined, channel}, client) do
    debug "Joined #{channel}"
    {:noreply, client}
  end

  def handle_info({:joined, channel, user}, client) do
    # ExIrc currently has a bug that doesn't remove the \r\n from the end
    # of the channel name with it sends along this kind of message
    # so we ensure any trailing or leading whitespace is explicitly removed
    channel = String.strip(channel)
    debug "#{user} joined #{channel}"
    # ExIrc.Client.msg(client, :privmsg, channel, "ohai #{user}")
    {:noreply, client}
  end

  def handle_info({:received, msg, user, channel}, client) do
    channel = String.strip(channel)
    [cmd | tail] = String.split(msg)

    cond do
      Regex.match?(~r/(http|https):\/\/osu.ppy.sh\/(s|b)\/(\d+)/i, msg) ->
        osuMatched = Regex.run(~r/(http|https):\/\/osu.ppy.sh\/(s|b)\/(\d+)/i, msg)
        osuMatched = List.to_tuple(osuMatched)
        handle_osu_request({channel, user, elem(osuMatched, 2), elem(osuMatched, 3)}, client)
    end

    {:noreply, client}
  end

  # Catch-all for messages you don't care about
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  defp debug(msg) do
    IO.puts IO.ANSI.yellow() <> msg <> IO.ANSI.reset()
  end

  def handle_osu_request({channel, user, type, id}, client) do
    atomChannel = List.to_atom(String.to_char_list(channel))
    osu_users = Application.get_env(:osu_requests, :osuuser)
    osu_ign = osu_users[atomChannel]
    if osu_ign !== nil do
      # Get JSON data with HTTPoison
      osu_apikey = Application.get_env(:osu_requests, :apikey)
      OsuApi.start

      # Parse JSON with JSON lib (jsons get parsed into maps into elixir)
      osu_json = OsuApi.get!("/get_beatmaps?k=#{osu_apikey}&#{type}=#{id}&m=0")

      map_data = hd(elem((Map.get(osu_json, :body)), 1))
      map_artist = Map.get(map_data, "artist")
      map_title = Map.get(map_data, "title")
      map_diff = Map.get(map_data, "version")
      map_BPM = Map.get(map_data, "bpm")
      map_star = Float.round(elem((Float.parse(Map.get(map_data, "difficultyrating"))), 0), 2) # round to 2 decimal places
      map_creator = Map.get(map_data, "creator")
      map_status_id = Map.get(map_data, "approved")
      map_status = "Unknown"

      # Check what rank status the map is
      case map_status_id do
        "3" -> map_status = "Qualified"
        "2" -> map_status = "Approved"
        "1" -> map_status = "Ranked"
        "0" -> map_status = "Pending"
        "-1" -> map_status = "WIP"
        "-2" -> map_status = "Graveyard"
      end

      # Send message to twitch to acknowledge, and send off to bancho
      ExIrc.Client.msg(client, :privmsg, channel, "#{user} requested: [#{map_status}] #{map_artist} - #{map_title} [#{map_diff}] (mapped by #{map_creator}) <#{map_BPM}BPM #{map_star}★>")
      ExIrc.Client.msg(:bancho_client, :privmsg, osu_ign, "#{user}: [http://osu.ppy.sh/#{type}/#{id} [#{map_status}] #{map_artist} - #{map_title} [#{map_diff}] (mapped by #{map_creator})] <#{map_BPM}BPM #{map_star}★> ")
    end
  end
end

defmodule OsuApi do
  use HTTPoison.Base

  def process_url(url) do
    "https://osu.ppy.sh/api" <> url
  end

  def process_response_body(body) do
    body
    |> JSON.decode
  end
end
