# Probes for the failure branches this file drives. They are defined here rather
# than borrowed from another test file: running a single test file compiles only
# that file, so a fixture that lives elsewhere is missing exactly when someone
# runs this file on its own.
defmodule Arca.Cli.OutcomeProbe.OutcomeleafCommand do
  use Arca.Cli.Command.BaseCommand

  config :outcomeleaf,
    name: "outcomeleaf",
    about: "Leaf command used to probe subcommand dispatch",
    args: [
      p1: [value_name: "P1", help: "first", required: false, parser: :string]
    ]

  @impl Arca.Cli.Command.CommandBehaviour
  def handle(args, _settings, _optimus), do: inspect(args)
end

defmodule Arca.Cli.OutcomeProbe.OutcomedispatcherCommand do
  use Arca.Cli.Command.BaseCommand
  use Arca.Cli.Command.BaseSubCommand

  config :outcomedispatcher,
    name: "outcomedispatcher",
    about: "Dispatcher used to probe subcommand dispatch",
    args: [
      cmd: [value_name: "CMD", help: "first", required: false, parser: :string]
    ],
    sub_commands: [Arca.Cli.OutcomeProbe.OutcomeleafCommand]
end

# A command module whose config/0 does not return the [{name, opts}] shape the
# coordinator requires. Nothing in the repo produces this shape, so it is built
# here to drive the failure branch that used to be swallowed.
defmodule Arca.Cli.OutcomeProbe.BrokenCommand do
  def config, do: :not_a_command_config
end

defmodule Arca.Cli.OutcomeChannelTest do
  @moduledoc """
  Covers the last four instances of finding A13 (WP-11: findings A18, A19, A20, A24).

  Each returned its failure as ordinary display text. A command's return value is
  the only thing dispatch reads to decide the exit status, so a failure rendered
  as a string IS a success: the message printed, the shell got 0, and a script
  testing `$?` carried on. In every case the fix is that the failure returns its
  error tuple and dispatch reports it.

  Coverage, stated plainly. A18 and A20 are driven behaviourally below, because
  their failure branches are reachable from outside. A19 (`cfg.list`) and A24
  (`sys.flush`) fail only when a dependency they call fails, and there is no seam
  to drive that without mocking our own modules, which IN-EX-TEST-006 forbids --
  so they are covered by the construct gate here plus the shared dispatch
  contract already proven in AC-01.1. The gate proves these four constructs
  cannot return; it does not prove a NEW one cannot appear.
  """
  use ExUnit.Case, async: true

  alias Arca.Cli.Configurator.Coordinator
  alias Arca.Cli.Configurator.DftConfigurator
  alias Arca.Cli.OutcomeProbe.BrokenCommand
  alias Arca.Cli.OutcomeProbe.OutcomedispatcherCommand

  @a13_sources [
    "lib/arca_cli/commands/base_sub_command.ex",
    "lib/arca_cli/commands/cfg_commands.ex",
    "lib/arca_cli/commands/sys_flush_command.ex",
    "lib/arca_cli/configurator/coordinator.ex"
  ]

  # The exact display strings each defect returned in place of an error tuple.
  @failure_as_display_text [
    ~s("Error: Failed to clear command history),
    ~s("Error loading settings: ),
    ~s("Error (),
    ~s("Parsing error: ),
    ~s("Command not found: )
  ]

  describe "A18: the shared subcommand base" do
    test "failure: a dispatch failure returns its error tuple rather than display text" do
      assert {:error, :invalid_arguments, message} =
               OutcomedispatcherCommand.handle(%{}, %{}, nil)

      assert message =~ "failed to extract arguments"
    end

    test "invariant: the failure is not a string, so dispatch can tell it from success" do
      refute is_binary(OutcomedispatcherCommand.handle(%{}, %{}, nil))
    end
  end

  describe "A20: the configurator coordinator" do
    test "failure: a broken command reports an error instead of returning the original config" do
      config = %{name: "probe", subcommands: []}

      assert {:error, :command_config_error, message} =
               Coordinator.inject_subcommands(config, [BrokenCommand])

      assert message =~ "failed to get command"
    end

    test "invariant: the original config is never returned as if injection had succeeded" do
      config = %{name: "probe", subcommands: [], marker: :untouched}

      refute Coordinator.inject_subcommands(config, [BrokenCommand]) == config
    end

    test "success: a well-formed command set still injects and reports ok" do
      config = %{name: "probe", subcommands: []}

      assert {:ok, %{subcommands: subcommands}} =
               Coordinator.inject_subcommands(config, [Arca.Cli.Commands.AboutCommand])

      assert Keyword.has_key?(subcommands, :about)
    end

    test "failure: a command whose name cannot be read halts instead of being skipped" do
      assert {:error, :command_config_error, _message} =
               Coordinator.update_command_names(%{}, [BrokenCommand], DftConfigurator)
    end

    test "success: readable command names accumulate against their configurator" do
      assert {:ok, %{about: [DftConfigurator]}} =
               Coordinator.update_command_names(
                 %{},
                 [Arca.Cli.Commands.AboutCommand],
                 DftConfigurator
               )
    end
  end

  describe "gate: the failure-as-display-text constructs stay gone" do
    test "invariant: none of the four A13 display strings remain in the sources" do
      assert sites(@failure_as_display_text) == []
    end

    test "control: the scanner reads these files and finds their error tuples" do
      assert length(sites([~s({:error,)])) > 5
    end
  end

  # Log lines are excluded: the gate is about what a function RETURNS, and a
  # Logger call returns :ok regardless of its wording. cfg.list legitimately logs
  # the same sentence it used to return. This skips the string of a Logger call
  # written across several lines too, which is the accepted limit of a line-wise
  # scanner -- the constructs it guards are all single-line.
  @spec sites([String.t()]) :: [String.t()]
  defp sites(needles) do
    for path <- @a13_sources,
        {line, number} <- Enum.with_index(String.split(File.read!(path), "\n"), 1),
        not String.contains?(line, "Logger."),
        needle <- needles,
        String.contains?(line, needle) do
      "#{path}:#{number}: #{String.trim(line)}"
    end
  end
end
