defmodule Database.Config do
  use Ecto.Model

  schema "config" do
    field :channel, :string, size: 255
    field :key, :string, size: 255
    field :value, :string, size: 255

    timestamps
  end
end
