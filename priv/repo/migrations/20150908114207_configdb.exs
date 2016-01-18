defmodule Twitchbot.Repo.Migrations.Configdb do
  use Ecto.Migration

  def change do
    create table(:config) do
      add :channel, :string, size: 255
      add :key, :string, size: 255
      add :value, :string, size: 255

      timestamps
    end
  end
end
