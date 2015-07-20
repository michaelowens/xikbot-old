# Module for handling osu! requests to xikbot in elixir
# by n2468txd
# http://n2468txd.github.io/
#
# In the config this module is activated for whatever channel which has an associated osu username
# If they don't then they are just ignored.

import RateLimiting

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

  def handle_info({:received, msg, user, channel}, client) do
    channel = String.strip(channel)

    cond do
      Regex.match?(~r/osu.ppy.sh\/(s|b)\/(\d+)/i, msg) ->
        #if user != String.strip(channel, ?#) do # Ignore broadcaster's map links
          osuMatched = Regex.run(~r/osu.ppy.sh\/(s|b)\/(\d+)/i, msg)
          osuMatched = List.to_tuple(osuMatched)
          handle_osu_request({channel, user, elem(osuMatched, 1), elem(osuMatched, 2)}, client)
        #end

      true -> nil
    end

    {:noreply, client}
  end

  # Catch-all for messages you don't care about
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  defp debug(msg) do
    IO.puts IO.ANSI.yellow() <> "[OSU_REQUESTS] " <> msg <> IO.ANSI.reset()
  end

  def handle_osu_request({channel, user, type, id}, client) do
    atomChannel = List.to_atom(String.to_char_list(channel))
    osu_users = Application.get_env(:osu_requests, :osuuser)
    osu_ign = osu_users[atomChannel]
    if osu_ign != nil do
      # Get JSON data with HTTPoison
      osu_apikey = Application.get_env(:osu_requests, :apikey)
      OsuApi.start

      # Parse JSON with JSON lib (jsons get parsed into maps into elixir)
      osu_json = OsuApi.get!("/get_beatmaps?k=#{osu_apikey}&#{type}=#{id}&m=0")

      # Element 1 as Element 0 is :ok indicator
      beatmaps_data = elem((osu_json.body), 1)

      # Check that the request isn't invalid (i.e. nothing in data)
      if beatmaps_data != [] do
        # Get first element in the JSON data (i.e. the hd()) as the hardest diff is usually the first one
        map_data = hd(beatmaps_data)
        map_artist = map_data |> Map.get("artist")
        map_title = map_data |> Map.get("title")
        map_diff = map_data |> Map.get("version")
        map_BPM = map_data |> Map.get("bpm")
        map_star = map_data |> Map.get("difficultyrating") |> Float.parse |> elem(0) |> Float.round(2) # round to 2 decimal places
        map_creator = map_data |> Map.get("creator")
        map_status_id = map_data |> Map.get("approved")

        # Check what rank status the map is
        map_status = "Unknown" # Default value
        case map_status_id do
          "3" -> map_status = "Qualified"
          "2" -> map_status = "Approved"
          "1" -> map_status = "Ranked"
          "0" -> map_status = "Pending"
          "-1" -> map_status = "WIP"
          "-2" -> map_status = "Graveyard"
        end

        # Send message to twitch to acknowledge, and send off to bancho
        debug("#{user}: [#{map_status}] #{map_artist} - #{map_title} [#{map_diff}] (mapped by #{map_creator})")
        ExIrc.Client.msg(client, :privmsg, channel, "#{user} requested: [#{map_status}] #{map_artist} - #{map_title} [#{map_diff}] (mapped by #{map_creator}) <#{map_BPM}BPM #{map_star}★>")
        rate_send_message({"bancho", 1_000, osu_ign, "#{user}: [http://osu.ppy.sh/#{type}/#{id} [#{map_status}] #{map_artist} - #{map_title} [#{map_diff}] (mapped by #{map_creator})] <#{map_BPM}BPM #{map_star}★> "}, :bancho_client)
      end
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
