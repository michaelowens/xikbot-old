defmodule User do
  import Ecto.Query

  def is_admin(user) do
    Application.get_env(:twitchbot, :admins)
      |> Enum.member? String.downcase user
  end

  def is_moderator(channel, user) when channel == user do
    true
  end

  def is_moderator(channel, user) do
    [u] = Twitchbot.Repo.all from u in Database.Moderator,
      where: u.channel == ^channel and u.user == ^user,
      select: count(u.id)
    u == 1
  end
end
