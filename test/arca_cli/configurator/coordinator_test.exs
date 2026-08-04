defmodule Arca.Cli.Configurator.CoordinatorTest.TestCfg8r1 do
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

defmodule Arca.Cli.Configurator.CoordinatorTest.TestCfg8r2 do
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

defmodule Arca.Cli.Configurator.Coordinator.Test do
  use ExUnit.Case
  import ExUnit.CaptureLog
  alias Arca.Cli.Configurator.Coordinator
  alias Arca.Cli.Configurator.DftConfigurator

  doctest Arca.Cli.Configurator.Coordinator

  describe "Arca.Cli.Configurator.Coordinator" do
    test "Coordinator.setup/0 uses default configurator" do
      config = Coordinator.setup()
      assert config.name == "arca_cli"
    end

    test "Coordinator.setup/1 handles single configurator" do
      config = Coordinator.setup(DftConfigurator)
      assert config.name == "arca_cli"
    end

    test "Coordinator.setup/1 handles multiple configurators" do
      config =
        Coordinator.setup([
          Arca.Cli.Configurator.CoordinatorTest.TestCfg8r1,
          Arca.Cli.Configurator.CoordinatorTest.TestCfg8r2
        ])

      assert config.name == "arca_cli_testcfg8r2"
      assert config.author == "Arca CLI AUTHOR TestCfg8r2"
    end

    test "Coordinator.setup/1 rejects duplicate configurators and logs warning" do
      log =
        capture_log(fn ->
          config =
            Coordinator.setup([
              Arca.Cli.Configurator.CoordinatorTest.TestCfg8r1,
              # duplicate
              Arca.Cli.Configurator.CoordinatorTest.TestCfg8r1,
              Arca.Cli.Configurator.CoordinatorTest.TestCfg8r2
            ])

          assert config.name == "arca_cli_testcfg8r2"
          assert config.author == "Arca CLI AUTHOR TestCfg8r2"
        end)

      assert log =~ "Duplicate configurators found and rejected"
    end

    test "Coordinator.setup/1 logs warning for duplicate subcommand names" do
      log =
        capture_log(fn ->
          config =
            Coordinator.setup([
              Arca.Cli.Configurator.CoordinatorTest.TestCfg8r1,
              Arca.Cli.Configurator.CoordinatorTest.TestCfg8r2
            ])

          assert config.name == "arca_cli_testcfg8r2"
          assert config.author == "Arca CLI AUTHOR TestCfg8r2"
        end)

      # The warning must name the winner, not just report the clash: registration
      # order decides, and TestCfg8r2 is registered last.
      assert log =~ ~s|Duplicate subcommand :"sys.flush" registered by|
      assert log =~ "last registered wins: Arca.Cli.Configurator.CoordinatorTest.TestCfg8r2"
    end
  end
end
