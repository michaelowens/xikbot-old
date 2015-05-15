defmodule Twitchbot.YouTube do
  alias Twitchbot.YouTube

  def start_link(client) do
    GenServer.start_link(__MODULE__, [client])
  end

  def init([client]) do
    ExIrc.Client.add_handler client, self
    {:ok, client}
  end

  def handle_info(:logged_in, state = {client, channels}) do
    YouTube.start
    {:noreply, state}
  end

  def handle_info({:received, msg, user, channel}, client) do
    channel = String.strip(channel)
    [cmd | tail] = String.split(msg)

    # debug "Youtube got message"

    case cmd do
      "!yt"  -> handle_yt({Enum.join(tail, " "), user, channel}, client)
      _      -> nil
    end

    {:noreply, client}
  end

  # Catch-all for messages you don't care about
  # def handle_info(_msg, state) do
  #   {:noreply, state}
  # end

  defp debug(msg) do
    IO.puts IO.ANSI.yellow() <> msg <> IO.ANSI.reset()
  end

  def handle_test({msg, user, channel}, client) do
    ExIrc.Client.msg(client, :privmsg, channel, "Test!")
  end

  @doc """
  Look for a youtube video via YouTube API v2
  https://gdata.youtube.com/feeds/api/videos?
    q=<query>
    &orderby=published
    &max-results=1
    &v=2
  """
  def handle_yt({msg, user, channel}, client) do
    debug "looking for youtube video: " <> msg
    params = %{q: msg, part: "snippet", maxResults: 1}
    response = YouTubePoison.get!("search", [], params: params)
    # response = YouTubePoison.get!("?q=" <> "test" <> "&part=snippet&maxResults=1")
    # response = YouTubePoison.get!("?q=" <> "test" <> "&orderby=published&max-results=1&v=2&alt=json")
    result = List.first(response.body["items"])
    title = result["snippet"]["title"]
    url = "http://youtu.be/" <> result["id"]["videoId"]
    ExIrc.Client.msg(client, :privmsg, channel, "@#{user} #{title} -- #{url}")
  end
end

defmodule YouTubePoison do
  alias YouTubePoison
  use HTTPoison.Base

  defmodule Response do
    defstruct [:id, :kind, :snippet]
  end

  def process_url(url) do
    "https://www.googleapis.com/youtube/v3/" <> url <> "&key=" <> Application.get_env(:Youtube, :key)
  end

  def process_response_body(body) do
    body
    |> Poison.decode! as: %{"body" => %{"items" => [%{"data" => Entry}]}}
    # |> Enum.map(fn({k, v}) -> {String.to_atom(k), v} end)
  end
end
