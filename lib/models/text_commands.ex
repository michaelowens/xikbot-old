defmodule Database.TextCommands do
  use Ecto.Model

  schema "textcommands" do
    field :channel, :string, size: 255
    field :command, :string, size: 255
    field :output, :string
    field :count, :integer, default: 0
    field :added_by, :string, size: 255

    timestamps
  end
end
