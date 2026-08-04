# A subcommand dispatcher whose declared argument order differs from the order
# `Map.keys/1` yields for those names -- and from the reverse of it, since the old
# implementation reversed. These four names give %{} the key order
# [:scope, :format, :cmd, :target], which matches neither.
defmodule Arca.Cli.ArgOrderProbe.LeafCommand do
  use Arca.Cli.Command.BaseCommand

  config :leaf,
    name: "leaf",
    about: "Leaf command",
    args: [
      p1: [value_name: "P1", help: "first", required: false, parser: :string]
    ]

  @impl Arca.Cli.Command.CommandBehaviour
  def handle(args, _settings, _optimus), do: inspect(args)
end

defmodule Arca.Cli.ArgOrderProbe.DispatcherCommand do
  use Arca.Cli.Command.BaseCommand
  use Arca.Cli.Command.BaseSubCommand

  config :dispatcher,
    name: "dispatcher",
    about: "Dispatcher",
    args: [
      cmd: [value_name: "CMD", help: "declared first", required: false, parser: :string],
      target: [value_name: "TARGET", help: "declared second", required: false, parser: :string],
      format: [value_name: "FORMAT", help: "declared third", required: false, parser: :string],
      scope: [value_name: "SCOPE", help: "declared fourth", required: false, parser: :string]
    ],
    sub_commands: [Arca.Cli.ArgOrderProbe.LeafCommand]
end

defmodule Arca.Cli.Command.BaseSubCommandArgOrderTest do
  @moduledoc """
  Covers argv reconstruction in `BaseSubCommand` (finding C12).

  `extract_arguments/1` rebuilt the argument vector with `Map.values/1`, which
  yields values in the map's own key order. That order is a function of how the
  names hash, not of how the user typed them -- for these four names it is
  `[:scope, :format, :cmd, :target]`. An `Enum.reverse/1` afterwards made the
  two-argument case come out right, and every subcommand in the repo had exactly
  two arguments, so the defect had nothing to trip over.

  The declaration is the only thing that knows the intended order, so that is
  what argv is now built from.
  """
  use ExUnit.Case, async: true

  alias Arca.Cli.ArgOrderProbe.DispatcherCommand

  @supplied %{cmd: "first", target: "second", format: "third", scope: "fourth"}

  describe "extract_arguments/1" do
    test "success: argv follows the order the arguments were declared in" do
      args = %{args: @supplied}

      assert DispatcherCommand.extract_arguments(args) ==
               {:ok, ["first", "second", "third", "fourth"]}
    end

    test "invariant: it is neither the map's key order nor the reverse of it" do
      map_order = Map.values(@supplied)

      {:ok, argv} = DispatcherCommand.extract_arguments(%{args: @supplied})

      refute argv == map_order
      refute argv == Enum.reverse(map_order)
    end

    test "success: arguments the user did not supply are omitted" do
      args = %{args: %{@supplied | target: nil, scope: nil}}

      assert DispatcherCommand.extract_arguments(args) == {:ok, ["first", "third"]}
    end

    test "success: no arguments at all yields an empty argv" do
      args = %{args: %{cmd: nil, target: nil, format: nil, scope: nil}}

      assert DispatcherCommand.extract_arguments(args) == {:ok, []}
    end
  end

  describe "sub_commands/0" do
    test "success: subcommands come from the config key, not a module attribute" do
      assert DispatcherCommand.sub_commands() == [Arca.Cli.ArgOrderProbe.LeafCommand]
    end
  end
end
