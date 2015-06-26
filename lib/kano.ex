defmodule Twitchbot.Kano do
  alias Twitchbot.Kano

  import Ecto.Query
  import Extension
  extends Plugin

  @bucket nil

  def start_link(client) do
    GenServer.start_link(__MODULE__, [client])
  end

  def handle_info({:received, msg, user, "#kano"}, client) do
    channel = String.strip("#kano")
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
