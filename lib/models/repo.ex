defmodule Twitchbot.Repo do
  use Ecto.Repo, otp_app: :twitchbot

  def priv do
    Application.app_dir(:twitchbot, "priv/repo")
  end
end
