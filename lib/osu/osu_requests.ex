# Module for handling osu! requests to xikbot in elixir
#
# In the config this module is activated for whatever channel which has an associated osu username
# If they don't then they are just ignored.

defmodule Twitchbot.OsuRequests do
  alias Twitchbot.OsuRequests

  import RateLimiting

  import Ecto.Query
  import Extension
  extends Plugin

  import HTTPoison

  def start_link(client) do
    Agent.start_link(fn -> HashDict.new end, name: __MODULE__) # To check if channel has enabled osu! requests
    update_agent() # Load database configs
    GenServer.start_link(__MODULE__, [client])
  end

  def init([client]) do
    ExIrc.Client.add_handler client, self
    {:ok, client}
  end

  def update_agent() do
    db_config = Twitchbot.Repo.all from c in Database.Config, where: c.key == "osu_requests", select: {c.channel, c.value}
    Agent.update(__MODULE__, fn _dict -> Enum.into(db_config, HashDict.new) end)
  end

  def modify_config(channel, value) do
    # Once again, similar logic to lib/kano.ex for update or insert
    selection = Twitchbot.Repo.all from c in Database.Config,
      where: c.channel == ^channel and c.key == "osu_requests",
      select: c

    if selection == [] do
      Twitchbot.Repo.insert %Database.Config{channel: channel, key: "osu_requests", value: value}
    else
      [selection] = selection
      Twitchbot.Repo.update %{selection | channel: channel, key: "osu_requests", value: value}
    end

    update_agent()
  end

  def handle_info({:received, msg, user, channel}, client) do
    channel = String.strip(channel)
    clean_channel = String.lstrip(channel, ?#)
    [cmd | tail] = String.split(msg)
    cmd = String.downcase(cmd)

    cond do
      Regex.match?(~r/osu.ppy.sh\/(s|b)\/(\d+)/i, msg) and (Agent.get(__MODULE__, &HashDict.get(&1, clean_channel)) == "true") ->
        #if user != String.strip(channel, ?#) do # Ignore broadcaster's map links
          osuMatched = Regex.run(~r/osu.ppy.sh\/(s|b)\/(\d+)/i, msg)
          osuMatched = List.to_tuple(osuMatched)
          handle_osu_request({channel, user, elem(osuMatched, 1), elem(osuMatched, 2)}, client)

      msg == "!#{Application.get_env(:twitchbot, :irc)[:nick]} osu" and User.is_moderator(clean_channel, user) ->
        if Agent.get(__MODULE__, &HashDict.get(&1, clean_channel)) == "true" do
          modify_config(clean_channel, "false")
          ExIrc.Client.msg(client, :privmsg, channel, "osu! requests have been disabled.")
        else
          modify_config(clean_channel, "true")
          ExIrc.Client.msg(client, :privmsg, channel, "osu! requests have been enabled!")
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
    IO.puts IO.ANSI.yellow() <> "[OSU_REQUESTS] " <> msg <> IO.ANSI.reset()
  end

  def handle_osu_request({channel, user, type, id}, client) do
    osu_users = Application.get_env(:osu, :requests)[:users]
    osu_ign = osu_users[:'#{channel}']
    if osu_ign != nil do
      # Get JSON data with HTTPoison
      osu_apikey = Application.get_env(:osu, :requests)[:api_key]

      # Parse JSON with JSX lib below in the api section (jsons get parsed into maps into elixir)
      beatmaps_data = HTTPoison.get!("https://osu.ppy.sh/api/get_beatmaps?k=#{osu_apikey}&#{type}=#{id}&m=0").body |> JSX.decode!

      # Check that the request isn't invalid (i.e. nothing in data)
      if beatmaps_data != [] do
        # Get first element in the JSON data (i.e. the hd()) as the hardest diff is usually the first one
        map_data = hd(beatmaps_data)
        map_artist = map_data["artist"]
        map_title = map_data["title"]
        map_diff = map_data["version"]
        map_BPM = map_data["bpm"]
        map_star = map_data["difficultyrating"] |> Float.parse |> elem(0) |> Float.round(2) # round to 2 decimal places
        map_creator = map_data["creator"]
        map_status_id = map_data["approved"]

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

        # Send message to twitch to acknowledge, and send off to osu irc
        debug("#{user}: [#{map_status}] #{map_artist} - #{map_title} [#{map_diff}] (mapped by #{map_creator})")
        ExIrc.Client.msg(client, :privmsg, channel, "#{user} requested: [#{map_status}] #{map_artist} - #{map_title} [#{map_diff}] (mapped by #{map_creator}) <#{map_BPM}BPM #{map_star}★>")
        rate_buffer_message("osu_irc", 1_000, osu_ign, "#{user}: [http://osu.ppy.sh/#{type}/#{id} [#{map_status}] #{map_artist} - #{map_title} [#{map_diff}] (mapped by #{map_creator})] <#{map_BPM}BPM #{map_star}★> ", :osu_client)
      end
    end
  end
end
