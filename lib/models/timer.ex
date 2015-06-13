defmodule Database.Timer do
  use Ecto.Model

  schema "timer" do
    field :cmd, :string, size: 255
    field :interval, :integer

    timestamps
  end
end
