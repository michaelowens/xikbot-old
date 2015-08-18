defmodule Twitchbot.Quotes do
  alias Twitchbot.Quotes

  import Ecto.Query
  import Extension
  extends Plugin

  def start_link(client) do
    GenServer.start_link(__MODULE__, [client])
  end

  def add_quote(channel, user, key, quote_text) do
    qu = %Database.Quotes{channel: channel, added_by: user, key: key, quote: quote_text}
    Twitchbot.Repo.insert qu
  end

  def get_quote(channel, key) do
    Twitchbot.Repo.all from q in Database.Quotes,
                     where: q.channel == ^channel and q.key == ^key,
                    select: q.quote
  end

  def handle_info({:received, msg, user, channel}, client) do
    channel = String.strip(channel)
    clean_channel = String.lstrip(channel, ?#)
    [cmd | tail] = String.split(msg)
    cmd = String.downcase(cmd)

    cond do
      cmd == "!quote" and tail != [] ->
        [quote_key | tail] = tail
        quo = get_quote(clean_channel, quote_key)
        if quo != [] do
          ExIrc.Client.msg(client, :privmsg, channel, "#{quo}")
        end

      cmd == "!addquote" and tail != [] and User.is_moderator(clean_channel, user) ->
        [quote_key | tail] = tail
        if tail != [] do
          tail = tail |> Enum.join(" ")
          add_quote(clean_channel, user, quote_key, tail)
          ExIrc.Client.msg(client, :privmsg, channel, "Quote '#{quote_key}' has been added.")
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
    IO.puts IO.ANSI.yellow() <> "[QUOTES] " <> msg <> IO.ANSI.reset()
  end

  def init([client]) do
    ExIrc.Client.add_handler client, self
    {:ok, client}
  end
end
