defmodule ExRated.Mixfile do
  use Mix.Project

  def project do
    [app: :ex_rated,
     version: "0.0.1",
     elixir: "~> 0.15.1",
     deps: deps]
  end

  # Configuration for the OTP application
  #
  # Type `mix help compile.app` for more information
  #
  # timeout :        bucket maximum lifetime (90_000_000, 25 hours)
  # cleanup_rate :   cleanup every X milliseconds (60_000, every 1 minute)
  # ets_table_name : the registered name of the ETS table where buckets are stored.
  def application do
    [applications: [:logger],
     env: [timeout: 90_000_000, cleanup_rate: 60_000, ets_table_name: :ex_rated_buckets],
     mod: {ExRated.App, []}]
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
    [{:ex2ms, "~> 1.2.0"}]
  end
end
