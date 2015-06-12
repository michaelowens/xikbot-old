defmodule Database.Timer do
  use Ecto.Model

  schema "timer" do
    field :cmd, :string, size: 255
    field :interval, :integer
    # field :last_run, :datetime, default: Ecto.DateTime.local
    timestamps
  end
end
