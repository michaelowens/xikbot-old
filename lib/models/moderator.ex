defmodule Database.Moderator do
  use Ecto.Model

  schema "moderator" do
    field :channel, :string, size: 255
    field :user, :string, size: 255

    timestamps
  end
end
