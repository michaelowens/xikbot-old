defmodule Database.Quotes do
  use Ecto.Model

  schema "quotes" do
    field :channel, :string, size: 255
    field :key, :string, size: 255
    field :quote, :string, size: 255
    field :added_by, :string, size: 255

    timestamps
  end
end
