defmodule Database.Channel do
  use Ecto.Model

  schema "channel" do
    field :name, :string, size: 255
    field :live, :boolean
    field :retries, :integer

    timestamps
  end
end
