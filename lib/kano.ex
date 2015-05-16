defmodule Twitchbot.Kano do
  alias Twitchbot.Kano

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
      Regex.match?(~r/ayy/i, msg) ->
        everyX(cmd, 60000, fn ->
          ExIrc.Client.msg(client, :privmsg, channel, ".me ayy pancakes")
        end)

      Regex.match?(~r/^(?=.*?(\bhow\b))(?=.*?(\bget\b))(?=.*?(bitches)).*$/i, msg) ->
        everyX(cmd, 60000, fn ->
          ExIrc.Client.msg(client, :privmsg, channel, ".me message A_BUNCH_OF_FAT_CHICKS on Twitch Kappa")
        end)

      cmd == "!xikbot" ->
        everyX(cmd, 10000, fn ->
          ExIrc.Client.msg(client, :privmsg, channel, ".me XikBot (v2) is a bot made by Xikeon (Michelle). Known for its great AI and unique triggers.")
        end)

      cmd == "!cereal" ->
        everyX(cmd, 10000, fn ->
          ExIrc.Client.msg(client, :privmsg, channel, ".me Get good, get Kanos! http://imgur.com/CUGTR2s")
        end)

      cmd == "!420" ->
        everyX(cmd, 60000, fn ->
          ExIrc.Client.msg(client, :privmsg, channel, ".me (_̅_̅_̅_̅_̲̅м̲̅a̲̅я̲̅i̲̅j­̲̅u̲̅a̲̅n̲̅a̲̅_̅_̅_̅()ด้้้้้็็็็็้้้้้็็็็็้้้้้้้้็็็็็้้้้้็็็็็้้้้้้้้็็็็็้้้้้็็็็็้้้้้้้้็็็็็")
        end)

      cmd == "!angels" ->
        everyX(cmd, 10000, fn ->
          ExIrc.Client.msg(client, :privmsg, channel, ".me (◕‿◕✿) Kano's Angels are Tina (Chibsta), Wendy (A_BUNCH_OF_FAT_CHICKS) and Michelle (Xikeon)")
        end)

      cmd == "!bigblack" ->
        everyX(cmd, 10000, fn ->
          ExIrc.Client.msg(client, :privmsg, channel, "https://osu.ppu.sh/s/41823")
        end)

      cmd == "!downtime" ->
        everyX(cmd, 10000, fn ->
          ExIrc.Client.msg(client, :privmsg, channel, "oi #{user}, u rly think ur funny m8?")
        end)

      true -> nil
    end

    # case cmd do
    #   # Simple replies
    #   "!downtime"   -> everyX(cmd, 5000, fn ->
    #     ExIrc.Client.msg(client, :privmsg, channel, "oi #{user}, u rly think ur funny m8?")
    #   end)

    #   ""

    #   _      -> nil
    # end

    {:noreply, client}
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
