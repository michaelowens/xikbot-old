defmodule Twitchbot.Mixfile do
  use Mix.Project

  def project do
    [app: :twitchbot,
     version: "0.0.2",
     elixir: "~> 1.0",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps]
  end

  # Configuration for the OTP application
  #
  # Type `mix help compile.app` for more information
  def application do
    [applications: [:exirc, :httpoison, :logger, :amnesia],
     mod: {Twitchbot, []}]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type `mix help deps` for more examples and options
  defp deps do
    [
      {:exirc, "~> 0.9.1"},
      {:poison, "~> 1.4"},
      {:httpoison, "~> 0.6"},
      {:mock, "~> 0.1.1"},
      {:amnesia, "~> 0.2.0", github: "meh/amnesia"},
      {:erlubi, github: "krestenkrab/erlubi"}
    ]
  end
end
