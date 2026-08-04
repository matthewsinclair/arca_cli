defmodule Arca.Cli.Commands.AboutCommandTest do
  use ExUnit.Case

  # Read from the single source so a version bump does not break these assertions.
  @version File.read!("VERSION") |> String.trim()

  alias Arca.Cli.Commands.AboutCommand
  alias Arca.Cli.Test.Support
  doctest Arca.Cli.Commands.AboutCommand

  describe "Arca.Cli.Commands.AboutCommand" do
    setup do
      # Get previous env var for config path and file names
      previous_env = System.get_env()

      # Set up to load the local .arca/config.json file
      System.put_env("ARCA_CONFIG_PATH", "./.arca")
      System.put_env("ARCA_CONFIG_FILE", "config.json")

      # Write a known config file to a known location
      Support.write_default_config_file(
        System.get_env("ARCA_CONFIG_FILE"),
        System.get_env("ARCA_CONFIG_PATH")
      )

      # Put things back how we found them
      on_exit(fn -> System.put_env(previous_env) end)

      :ok
    end

    test "success: config/0 declares the about command" do
      assert [about: config_opts] = AboutCommand.config()

      assert Keyword.get(config_opts, :name) == "about"
      assert Keyword.get(config_opts, :about) == "Info about the command line interface."

      assert Keyword.get(config_opts, :help) =~
               "displays basic information about the CLI application"
    end

    test "success: handle/3 returns the CLI about text" do
      assert AboutCommand.handle(nil, nil, nil) |> String.trim() ==
               """
               📦 Arca CLI
               A declarative CLI for Elixir apps
               https://arca.io
               arca_cli #{@version}
               """
               |> String.trim()
    end
  end
end
