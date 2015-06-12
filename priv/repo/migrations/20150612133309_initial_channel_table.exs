defmodule Twitchbot.Repo.Migrations.InitialChannelTable do
  use Ecto.Migration

  def change do
    create table(:channel) do
      add :name, :string, size: 255
      add :live, :boolean
      add :interval, :integer

      timestamps
    end
  end
end
