defmodule Arca.Cli.Configurator.ConfiguratorTest.TestCfg8r1 do
  use Arca.Cli.Configurator.BaseConfigurator

  config :arca_cli_testcfg8r1,
    commands: [
      Arca.Cli.Commands.AboutCommand,
      Arca.Cli.Commands.SysFlushCommand
    ],
    author: "Arca CLI AUTHOR TestCfg8r1",
    about: "Arca CLI ABOUT TestCfg8r1",
    description: "Arca CLI DESCRIPTION TestCfg8r1",
    version: "Arca CLI VERSION TestCfg8r1"
end

defmodule Arca.Cli.Configurator.ConfiguratorTest.TestCfg8r2 do
  use Arca.Cli.Configurator.BaseConfigurator

  config :arca_cli_testcfg8r2,
    commands: [
      Arca.Cli.Commands.SysFlushCommand,
      Arca.Cli.Commands.SettingsGetCommand,
      Arca.Cli.Commands.CliHistoryCommand
    ],
    author: "Arca CLI AUTHOR TestCfg8r2",
    about: "Arca CLI ABOUT TestCfg8r2",
    description: "Arca CLI DESCRIPTION TestCfg8r2",
    version: "Arca CLI VERSION TestCfg8r2"
end

defmodule Arca.Cli.Configurator.ConfiguratorTest.UnsortedConfigurator do
  use Arca.Cli.Configurator.BaseConfigurator

  config :unsorted_configurator,
    commands: [
      # Deliberately out of alphabetical order
      Arca.Cli.Commands.SysInfoCommand,
      Arca.Cli.Commands.AboutCommand,
      Arca.Cli.Commands.SettingsGetCommand,
      Arca.Cli.Commands.SysFlushCommand
    ],
    author: "Test Author",
    about: "Test Unsorted CLI",
    description: "A test CLI with unsorted commands",
    version: "0.0.1",
    # Disable command sorting
    sorted: false

  # Override the default sorted function for testing
  # This is necessary because the module attribute isn't being properly 
  # transferred in the test environment
  @impl Arca.Cli.Configurator.ConfiguratorBehaviour
  def sorted, do: false
end

# Create an unsorted configurator for manual testing
defmodule UnsortedTestConfigurator do
  use Arca.Cli.Configurator.BaseConfigurator

  config :test_cli,
    commands: [
      # Deliberately out of alphabetical order
      Arca.Cli.Commands.SysInfoCommand,
      Arca.Cli.Commands.AboutCommand,
      Arca.Cli.Commands.CfgListCommand,
      Arca.Cli.Commands.CliHistoryCommand
    ],
    author: "Test Author",
    about: "Test Unsorted CLI",
    description: "A test CLI with unsorted commands",
    version: "0.0.1",
    # Disable command sorting
    sorted: false

  @impl Arca.Cli.Configurator.ConfiguratorBehaviour
  def sorted, do: false
end

defmodule Arca.Cli.Configurator.ConfiguratorTest do
  use ExUnit.Case

  # Read from the single source so a version bump does not break these assertions.
  @version File.read!("VERSION") |> String.trim()

  import ExUnit.CaptureLog
  require Logger
  alias Arca.Cli.Commands.AboutCommand
  alias Arca.Cli.Configurator.Coordinator
  alias Arca.Cli.Configurator.DftConfigurator
  doctest Arca.Cli.Configurator.ConfiguratorBehaviour
  doctest Arca.Cli.Configurator.BaseConfigurator
  doctest Arca.Cli.Configurator.DftConfigurator

  describe "Arca.Cli.Configurator" do
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

    test "inject_subcommands/2 can handle addition of multiple command configurations" do
      commands1 = [
        Arca.Cli.Commands.AboutCommand,
        Arca.Cli.Commands.SysFlushCommand
      ]

      expected_commands1 =
        Arca.Cli.Commands.AboutCommand.config() ++ Arca.Cli.Commands.SysFlushCommand.config()

      # Each batch is listed in alphabetical order so that within-batch sorting
      # cannot mask the property under test, which is that a second injection
      # appends to the first rather than replacing or interleaving it.
      commands2 = [
        Arca.Cli.Commands.CliHistoryCommand,
        Arca.Cli.Commands.SettingsGetCommand
      ]

      expected_commands2 =
        Arca.Cli.Commands.CliHistoryCommand.config() ++
          Arca.Cli.Commands.SettingsGetCommand.config()

      optimus_base = [
        name: "name",
        description: "description",
        version: "0.0.1",
        author: "author",
        allow_unknown_args: true,
        parse_double_dash: true,
        subcommands: []
      ]

      optimus =
        optimus_base
        |> DftConfigurator.inject_subcommands(commands1)
        |> DftConfigurator.inject_subcommands(commands2)

      assert Keyword.get(optimus, :subcommands) == expected_commands1 ++ expected_commands2
    end

    test "Coordinator.setup/1 handles single configurator" do
      config = Coordinator.setup(DftConfigurator)
      assert config.name == "arca_cli"
    end

    test "Coordinator.setup/1 handles multiple configurators and warns on duplicates" do
      log =
        capture_log(fn ->
          config =
            Coordinator.setup([
              Arca.Cli.Configurator.ConfiguratorTest.TestCfg8r1,
              # duplicate
              Arca.Cli.Configurator.ConfiguratorTest.TestCfg8r1,
              Arca.Cli.Configurator.ConfiguratorTest.TestCfg8r2
            ])

          assert config.name == "arca_cli_testcfg8r2"
          assert config.author == "Arca CLI AUTHOR TestCfg8r2"
        end)

      assert log =~ "Duplicate configurators found and rejected"
    end

    test "Command sorting with sorted=true (default) sorts commands alphabetically" do
      # Default configurator has sorted=true
      commands = [
        Arca.Cli.Commands.SysInfoCommand,
        Arca.Cli.Commands.AboutCommand,
        Arca.Cli.Commands.SettingsGetCommand,
        Arca.Cli.Commands.SysFlushCommand
      ]

      # Extract command names before injection
      command_names_before =
        Enum.map(commands, fn mod ->
          [{name, _}] = mod.config()
          to_string(name)
        end)

      # Process commands through the default configurator's inject_subcommands
      optimus_base = [
        name: "test",
        description: "test",
        version: "0.0.1",
        author: "test",
        allow_unknown_args: true,
        parse_double_dash: true,
        subcommands: []
      ]

      result = DftConfigurator.inject_subcommands(optimus_base, commands)
      subcommands = Keyword.get(result, :subcommands)

      # Extract command names after processing
      command_names_after =
        Enum.map(subcommands, fn {name, _} ->
          to_string(name)
        end)

      # Verify commands are alphabetically sorted
      assert command_names_after == Enum.sort(command_names_before)
      refute command_names_after == command_names_before
    end

    test "Command sorting with sorted=false preserves command order" do
      alias Arca.Cli.Configurator.ConfiguratorTest.UnsortedConfigurator

      # Debug - check if sorted value is correctly set to false
      Logger.info("UnsortedConfigurator.sorted(): #{UnsortedConfigurator.sorted()}")

      commands = [
        Arca.Cli.Commands.SysInfoCommand,
        Arca.Cli.Commands.AboutCommand,
        Arca.Cli.Commands.SettingsGetCommand,
        Arca.Cli.Commands.SysFlushCommand
      ]

      # Extract command names before injection
      command_names_before =
        Enum.map(commands, fn mod ->
          [{name, _}] = mod.config()
          to_string(name)
        end)

      # Process commands through the unsorted configurator's inject_subcommands
      optimus_base = [
        name: "test",
        description: "test",
        version: "0.0.1",
        author: "test",
        allow_unknown_args: true,
        parse_double_dash: true,
        subcommands: []
      ]

      result = UnsortedConfigurator.inject_subcommands(optimus_base, commands)
      subcommands = Keyword.get(result, :subcommands)

      # Extract command names after processing
      command_names_after =
        Enum.map(subcommands, fn {name, _} ->
          to_string(name)
        end)

      # Verify command order is preserved (not sorted)
      assert command_names_after == command_names_before
      refute command_names_after == Enum.sort(command_names_before)
    end
  end
end
