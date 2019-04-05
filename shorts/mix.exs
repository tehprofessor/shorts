defmodule Shorts.MixProject do
  use Mix.Project

  def project do
    [
      app: :shorts,
      version: "0.1.0",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Shorts.Application, []}
    ]
  end

  defp deps do
    [
      {:persistent_ets, "~> 0.1.0"},
      {:wyhash_ex, path: "../wyhash_ex"}
    ]
  end
end
