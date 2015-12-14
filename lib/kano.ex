defmodule Twitchbot.Kano do
  alias Twitchbot.Kano

  import Ecto.Query
  import Extension
  extends Plugin

  @bucket nil

  @days ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"]

  def start_link(client) do
    GenServer.start_link(__MODULE__, [client])
  end

  def handle_info({:received, msg, user, "#kano"}, client) do
    channel = String.strip("#kano")
    clean_channel = String.lstrip(channel, ?#)
    [cmd | tail] = String.split(msg)
    cmd = String.downcase(cmd)

    cond do
      Regex.match?(~r/\bayy/i, msg) ->
        every_x("ayy", 60000, channel, ".me ayy pancakes")

      Regex.match?(~r/nice([.,]+)?[\s]+dude/i, msg) ->
        every_x("nice dude", 30000, channel, ".me dude nice")

      Regex.match?(~r/dude([.,]+)?[\s]+nice/i, msg) ->
        every_x("dude nice", 30000, channel, ".me nice dude")

      Regex.match?(~r/^(?=.*?(\bhow\b))(?=.*?(\bget\b))(?=.*?(bitches)).*$/i, msg) ->
        every_x("howgetbitches", 60000, channel, ".me message A_BUNCH_OF_FAT_CHICKS on Twitch Kappa")

      Regex.match?(~r/why does it rain/i, msg) ->
        rain_explanation = "When water becomes warm enough, it evaporates as vapor into the air. When a mass of air "
          <> "quickly cools to its saturation point, the water vapor condenses into clusters of tiny water droplets "
          <> "and frozen water crystals."
        rain_explanation2 = "We call these clusters clouds. Over time, the droplets and crystals that "
          <> "make up a cloud can attract more water to themselves. When water droplets grow heavy enough, gravity "
          <> "pulls them down as raindrops. If the air is cold enough, the ice crystals can remain frozen and grow "
          <> "large enough to fall as snow, sleet, freezing rain or hail."
        every_x("whydoesitrain", 66_666_666, channel, ".me " <> rain_explanation)
        every_x("whydoesitrain2", 66_666_666, channel, ".me " <> rain_explanation2)

      cmd == "!love2" ->
        every_x("love", 15_000, fn ->
          if not Enum.empty? tail do
            love_user = user |> String.downcase
            love_partner = tail |> Enum.join " "
            case {love_user, (love_partner |> String.downcase)} do
              {_, "xikbot"} ->
                ExIrc.Client.msg(client, :privmsg, channel, "Wow someone actually loves me... I love you too #{user}! AngelThump")

              {_, ^love_user} ->
                ExIrc.Client.msg(client, :privmsg, channel, "Wow #{user} really loves themselves too much KappaPride")

              {"chibsta", "freedman"} ->
                ExIrc.Client.msg(client, :privmsg, channel, "There's 100% <3 between Chibsta and ∠(ﾟДﾟ)／FREEEEEEDMAN !!")

              _ ->
                user_seed = love_user |> to_char_list |> Enum.join |> String.to_integer
                partner_seed = love_partner |> String.downcase |> to_char_list |> Enum.join |> String.to_integer
                datetime = :os.timestamp |> :calendar.now_to_datetime |> elem(0)
                day_index = datetime |> :calendar.day_of_the_week
                day_index = day_index - 1

                {:ok, day} = @days |> Enum.fetch day_index
                day = day |> to_char_list
                date_seed = datetime |> Tuple.to_list
                date_seed = Enum.concat day, date_seed
                date_seed = date_seed |> Enum.join |> String.to_integer
                # Erlang timestamp and return as {date tuple, time tuple}, grab that date and join it into a seed usable
                :random.seed({user_seed, partner_seed, date_seed}) # Set the random seed
                love = (:random.uniform * 100) |> Float.to_string [decimals: 0]
                ExIrc.Client.msg(client, :privmsg, channel, "There's #{love}% <3 between #{user} and #{love_partner}")
            end
          end
        end)

      (matches = Regex.named_captures(~r/(?:(?<name>xikbot)(?:[\d,.\s]+))?(?<message>((?:i(\s+))?love(?!(\s+)you)\b|(?:i(\s+))?love(\s+)you\b|ily|ly))(?:(?:[\d,.\s]+)(?<name2>xikbot))?/i, msg)) != nil ->
        response = false

        if String.downcase(matches["name"]) == "xikbot" do
          if not Regex.match?(~r/^i(\s+)love$/i, matches["message"]) do
            response = true
          end
        end

        if String.downcase(matches["name2"]) == "xikbot" do
          response = true
        end

        if response do
          every_x("iloveyou", 40000, channel, "I love you too, #{user} <3")
        end

      cmd == "!xikbot" ->
        every_x(cmd, 10000, channel, ".me XikBot (v2) is a bot made by Xikeon (Michelle). Known for its great AI and unique triggers.")

      cmd == "!cereal" ->
        every_x(cmd, 10000, channel, ".me Get good, get Kanos! http://imgur.com/CUGTR2s")

      cmd == "!420" or cmd == "420" ->
        every_x("420", 30*60000, channel, ".me (_̅_̅_̅_̅_̲̅м̲̅a̲̅я̲̅i̲̅j­̲̅u̲̅a̲̅n̲̅a̲̅_̅_̅_̅()ด้้้้้็็็็็้้้้้็็็็็้้้้้้้้็็็็็้้้้้็็็็็้้้้้้้้็็็็็้้้้้็็็็็้้้้้้้้็็็็็")

      cmd == "!angels" ->
        every_x(cmd, 10000, channel, ".me (◕‿◕✿) Kano's Angels are Tina (Chibsta), Wendy (A_BUNCH_OF_FAT_CHICKS) and Michelle (Xikeon)")

      cmd == "!bigblack" ->
        every_x(cmd, 10000, channel, "https://osu.ppy.sh/s/41823")

      cmd == "!downtime" ->
        every_x(cmd, 10000, channel, "oi #{user}, u rly think ur funny m8?")

      cmd == "!chibsta" or cmd == "!freedman" ->
        every_x("freedman", 2000, channel, "∠(ﾟДﾟ)／FREEEEEEDMAN !!")

      cmd == "!brainpower" ->
        every_x("brainpower", 2000, channel, ".me O-oooooooooo AAAAE-A-A-I-A-U- JO-oooooooooooo AAE-O-A-A-U-U-A- E-eee-ee-eee AAAAE-A-E-I-E-A-JO-ooo-oo-oo-oo EEEEO-A-AAA-AAAA")

      cmd == "!zowiegear" ->
        every_x("zowiegear", 30000, channel, ".me www.zowiegear.com Strive For Perfection")

      true -> nil
    end

    {:noreply, client}
  end

  def check_live_status(channel \\ "kano") do
    q = from c in Database.Channel,
      where: c.name == ^channel,
      select: c
    selection = Twitchbot.Repo.all q
    IO.puts(IO.inspect(selection))
  end

  def set_live_status(live, channel \\ "kano") do
    selection = Twitchbot.Repo.all from c in Database.Channel,
      where: c.name == ^channel,
      select: c

    if selection == [] do
      Twitchbot.Repo.insert %Database.Channel{name: channel, live: live, retries: 0}
    else
      [selection] = selection
      {:ok, retries, live} = cond do
        !live && selection.live && selection.retries < 2 ->
          {:ok, selection.retries + 1, true}

        selection.retries > 0 ->
          {:ok, 0, live}

        true -> {:ok, selection.retries, live}
      end

      Twitchbot.Repo.update %{selection | live: live, retries: retries, updated_at: Ecto.DateTime.local()}
    end
  end

  # Catch-all for messages you don't care about
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  defp debug(msg) do
    IO.puts IO.ANSI.yellow() <> msg <> IO.ANSI.reset()
  end

  def init([client]) do
    ExIrc.Client.add_handler client, self
    {:ok, client}
  end
end

defmodule TwitchPoison do
  alias TwitchPoison
  use HTTPoison.Base

  defmodule Response do
    defstruct [:id, :kind, :snippet]
  end

  def process_url(channel) do
    "https://api.twitch.tv/kraken/streams/" <> channel
  end

  def process_response_body(body) do
    body
    |> Poison.decode!
    # |> Enum.map(fn({k, v}) -> {String.to_atom(k), v} end)
  end
end
