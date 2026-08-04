defmodule Arca.Cli.CtxUsageTest do
  @moduledoc """
  Covers how in-repo commands build their `Ctx` (finding A11).

  Three commands called `Ctx.new(:"some.command", settings)`, passing the command
  atom into the `args` position. `Ctx.new/3` takes the command as an *option*, so
  those contexts came out with `command: nil` and an atom sitting where a map of
  arguments belongs. Nothing complained: `args` is never pattern-matched on the
  way to a renderer, so the misuse survived all the way to output.

  The cost is not cosmetic. `ctx.command` is what a JSON consumer keys on and what
  `dump` reports, so every one of those commands was anonymous in machine-readable
  output, and `ctx.args` lied about what the user typed.
  """
  use ExUnit.Case, async: true

  alias Arca.Cli.Ctx

  @parse_result %{args: %{}, options: %{}, flags: %{}, unknown: []}

  describe "Ctx.new/3 argument guard" do
    test "success: a map of arguments is accepted" do
      ctx = Ctx.new(%{name: "value"}, %{})

      assert ctx.args == %{name: "value"}
    end

    test "success: nil arguments normalise to an empty map" do
      ctx = Ctx.new(nil, %{})

      assert ctx.args == %{}
    end

    test "failure: a command atom in the args position raises and names the fix" do
      error =
        assert_raise ArgumentError, fn ->
          Ctx.new(:"sys.info", %{})
        end

      assert error.message =~ "sys.info"
      assert error.message =~ "for_command"
    end
  end

  describe "Ctx.for_command/4" do
    test "success: the command atom lands on :command, not on :args" do
      ctx = Ctx.for_command(:"sys.info", @parse_result, %{})

      assert ctx.command == :"sys.info"
      assert ctx.args == @parse_result
    end

    test "success: nil arguments still produce a map" do
      ctx = Ctx.for_command(:"sys.info", nil, %{})

      assert ctx.command == :"sys.info"
      assert ctx.args == %{}
    end

    test "success: extra options are carried through" do
      ctx = Ctx.for_command(:"sys.info", %{}, %{}, options: %{verbose: true})

      assert ctx.command == :"sys.info"
      assert ctx.options == %{verbose: true}
    end
  end

  describe "in-repo commands build a well-formed Ctx" do
    test "success: sys.info names itself and carries a map of args" do
      ctx = Arca.Cli.Commands.SysInfoCommand.handle(@parse_result, %{}, nil)

      assert ctx.command == :"sys.info"
      assert ctx.args == @parse_result
    end

    test "success: cli.history names itself and carries a map of args" do
      ctx = Arca.Cli.Commands.CliHistoryCommand.handle(@parse_result, %{}, nil)

      assert ctx.command == :"cli.history"
      assert ctx.args == @parse_result
    end

    test "success: settings.all names itself and carries a map of args" do
      ctx = Arca.Cli.Commands.SettingsAllCommand.handle(@parse_result, %{}, nil)

      assert ctx.command == :"settings.all"
      assert ctx.args == @parse_result
    end
  end
end
