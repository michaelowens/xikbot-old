defmodule Database.Blacklist do
  use Ecto.Model

  schema "blacklist" do
    field :channel, :string, size: 255
    field :pattern, :string, size: 255
    field :time, :integer, default: 600
    field :is_perm_ban, :boolean, default: false
    field :added_by, :string, size: 255

    timestamps
  end
end
