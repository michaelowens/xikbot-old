defmodule Twitchbot.Spam do
  alias Twitchbot.Spam

  import Extension
  extends Plugin

  def start_link(client) do
    GenServer.start_link(__MODULE__, [client])
  end

  def blacklistUrls do
    [
      "steamtrick.com", "screenhost.name", "hearthstonepromotions.com", "sleamcommuniiy.com", "steamcommunerity.com",
      "prtscrhost.name", "screenshot.name", "spinnerzone.com", "screenweb.name", "twitchsupport.gq", "screenweb.pw",
      "prtscnhost.pw", "staemcommunitry.com", "steramcomqmunity.com", "stearmcommqunity.com", "twiRch.tv", "tidyfile.net"
    ]
  end

  def handle_info({:received, msg, user, channel}, client) do
    channel = String.strip(channel)
    blacklist = Enum.join(blacklistUrls, "|")

    # debug "Spam got message"

    if Regex.match?(~r/(#{blacklist})/, msg) do
      ExIrc.Client.msg(client, :privmsg, channel, ".timeout #{user} 600")
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
