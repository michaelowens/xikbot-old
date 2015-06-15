defmodule Twitchbot.Repo.Migrations.InitialModeratorTable do
  use Ecto.Migration

  def change do
    create table(:moderator) do
      add :channel, :string, size: 255
      add :user, :string, size: 255

      timestamps
    end
  end
end
