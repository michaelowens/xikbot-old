defmodule Twitchbot.Repo.Migrations.TextCommandsMigration do
  use Ecto.Migration

  def change do
    create table(:textcommands) do
      add :channel, :string, size: 255
      add :command, :string, size: 255
      add :output, :string, size: 255
      add :added_by, :string, size: 255

      timestamps
    end
  end
end
