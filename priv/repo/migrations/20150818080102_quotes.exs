defmodule Twitchbot.Repo.Migrations.Quotes do
  use Ecto.Migration

  def change do
    create table(:quotes) do
      add :channel, :string, size: 255
      add :key, :string, size: 255
      add :quote, :string, size: 255
      add :added_by, :string, size: 255

      timestamps
    end
  end
end
