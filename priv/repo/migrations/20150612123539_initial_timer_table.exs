defmodule Database.Repo.Migrations.InitialTimerTable do
  use Ecto.Migration

  def change do
    create table(:timer) do
      add :cmd, :string, size: 255
      add :interval, :integer

      timestamps
    end

  end
end
