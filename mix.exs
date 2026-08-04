defmodule Arca.Cli.MixProject do
  use Mix.Project

  @version File.read!("VERSION") |> String.trim()

  def project do
    [
      app: :arca_cli,
      version: @version,
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),
      test_paths: ["test"],
      test_pattern: "*_test.exs",
      escript: [main_module: Arca.Cli, path: "_build/escript/arca_cli", name: "arca_cli"]
    ]
  end

  def application do
    # `ansi_enabled: true` used to be declared here. It forced colour on before
    # anything could ask where the output was going, which pushed escape codes
    # into pipes and files. The runtime already works out at boot whether stdout
    # is a terminal; the fix was to stop overriding its answer (WP-04).
    [
      mod: {Arca.Cli, []}
    ]
  end

  defp deps do
    [
      {:optimus, github: "matthewsinclair/arca-optimus", branch: "main", override: true},
      {:arca_config, github: "matthewsinclair/arca-config", branch: "main", override: true},
      {:jason, "~> 1.4"},
      {:owl, "~> 0.12"},
      {:ex_prompt, "~> 0.2"},

      # Dev/test tools
      {:ex_doc, "~> 0.29", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    ]
  end

  # Specifies which paths to compile per environment
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
