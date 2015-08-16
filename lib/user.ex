defmodule User do
  import Ecto.Query

  def is_admin(user) do
    Application.get_env(:twitchbot, :admins)
      |> Enum.member? String.downcase user
  end

  def is_moderator(channel, user) when channel == user do
    Application.get_env(:twitchbot, :irc)[:channels] # Check if we actually care about this person
      |> Enum.member? "#" <> String.downcase user
  end

  def is_moderator(channel, user) do
    [u] = Twitchbot.Repo.all from u in Database.Moderator,
      where: u.channel == ^channel and u.user == ^user,
      select: count(u.id)
    u == 1

    if is_admin(user) do # Admin override
      true
    end
  end
end
