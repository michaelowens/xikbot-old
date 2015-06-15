defmodule Twitchbot.Repo.Migrations.InitialBlacklistTable do
  use Ecto.Migration

  def change do
    create table(:blacklist) do
      add :channel, :string, size: 255
      add :pattern, :string, size: 255
      add :time, :integer, default: 600
      add :is_perm_ban, :boolean, default: false
      add :added_by, :string, size: 255

      timestamps
    end
  end
end
