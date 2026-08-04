defmodule Arca.Cli.VersionTest do
  @moduledoc """
  Covers version truth: one source, reported honestly everywhere.

  Before this, three sources disagreed -- the VERSION file said 0.4.3, an app-env
  copy in config.exs said 0.1.0, and the configurator carried the literal string
  "Arca CLI VERSION". `--version` printed none of them, because Optimus's
  `:version` parse result fell through to the help screen.

  These tests read the VERSION file at runtime rather than hardcoding a number,
  so bumping the release does not make them fail.
  """
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  @version File.read!("VERSION") |> String.trim()

  # Run the CLI in-process, returning both halves of what the user experiences.
  @spec run_cli([String.t()]) :: {Arca.Cli.outcome(), String.t()}
  defp run_cli(argv) do
    {outcome, io} = with_io(fn -> Arca.Cli.run(argv) end)
    {outcome, String.trim(io)}
  end

  describe "--version" do
    test "success: prints the app name and the VERSION file contents, and succeeds" do
      assert run_cli(["--version"]) == {:ok, "#{Arca.Cli.name()} #{@version}"}
    end

    test "invariant: does not print the help screen" do
      {:ok, output} = run_cli(["--version"])

      refute output =~ "USAGE:"
      refute output =~ "SUBCOMMANDS:"
    end
  end

  describe "version reporting" do
    test "success: about reports the VERSION file contents" do
      {:ok, output} = run_cli(["about"])

      assert output =~ @version
    end

    test "invariant: no placeholder strings survive in about" do
      {:ok, output} = run_cli(["about"])

      refute output =~ "Arca CLI VERSION"
      refute output =~ "Arca CLI ABOUT"
      refute output =~ "Arca CLI AUTHOR"
      refute output =~ "Arca CLI DESCRIPTION"
    end

    test "invariant: the default configurator carries no placeholder values" do
      config = Arca.Cli.Configurator.DftConfigurator.config()

      assert config.version == @version
      refute config.about =~ "Arca CLI ABOUT"
      refute config.author =~ "Arca CLI AUTHOR"
      refute config.description =~ "Arca CLI DESCRIPTION"
    end

    test "invariant: Arca.Cli.version/0 and the configurator agree" do
      assert Arca.Cli.version() == Arca.Cli.Configurator.DftConfigurator.version()
      assert Arca.Cli.version() == @version
    end
  end
end
