defmodule User do
  import Ecto.Query

  def is_moderator(channel, user) do
    [u] = Twitchbot.Repo.all from u in Database.Moderator,
      where: u.channel == ^channel and u.user == ^user,
      select: count(u.id)
    u
  end
end
