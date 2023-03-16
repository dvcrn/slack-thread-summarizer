defmodule Summarizer.MixProject do
  use Mix.Project

  def project do
    [
      app: :summarizer,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      releases: [
        summarizer: [
          include_executables_for: [:unix],
          applications: [runtime_tools: :permanent]
        ]
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Summarizer.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # {:slack, "~> 0.23.5"},
      {:ex_openai, ">= 1.0.4"},
      {:websockex, "~> 0.4.3"},
      {:jason, "~> 1.4"}

      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:slack, git: "https://github.com/BlakeWilliams/Elixir-Slack.git", tag: "v0.23.6"}
    ]
  end
end
