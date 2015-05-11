defmodule Twitchbot.Spam do
  alias Twitchbot.Spam

  import Extension
  extends Plugin

  def module, do: __MODULE__

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

    if Regex.match?(~r/(#{blacklist})/, msg) do
      ExIrc.Client.msg(client, :privmsg, channel, ".timeout #{user} 600")
    end

    {:noreply, client}
  end
end
