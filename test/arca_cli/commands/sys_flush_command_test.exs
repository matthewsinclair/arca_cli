defmodule Arca.Cli.Commands.SysFlushCommandTest do
  @moduledoc """
  Covers the registered `sys.flush`.

  This replaces a test of `Arca.Cli.Commands.FlushCommand`, an unregistered
  duplicate deleted in WP-07. That test was the only direct coverage of flushing,
  and it pointed at the module no user could reach -- so the command that ships
  had none, and the command that had one did not ship.
  """
  use ExUnit.Case, async: false

  alias Arca.Cli.Commands.SysFlushCommand
  alias Arca.Cli.History
  alias Arca.Cli.Test.Support

  setup do
    Support.ensure_history_started()

    # History is a named process shared by every test module, so it arrives
    # holding whatever ran before this. A test that asserts on a count has to
    # establish the count it is starting from, or it passes only when it happens
    # to run first.
    History.flush_history()

    :ok
  end

  describe "config/0" do
    test "success: it declares the sys.flush command" do
      assert SysFlushCommand.config() == [
               "sys.flush": [
                 name: "sys.flush",
                 about: "Flush the command history."
               ]
             ]
    end
  end

  describe "handle/3" do
    test "success: it empties the history" do
      History.push_cmd("about")
      History.push_cmd("sys.info")
      {:ok, before_flush} = History.get_history()
      assert length(before_flush) == 2

      SysFlushCommand.handle(nil, nil, nil)

      assert History.get_history() == {:ok, []}
    end

    test "success: it reports what it did" do
      assert SysFlushCommand.handle(nil, nil, nil) == "Command history cleared successfully"
    end

    test "invariant: flushing an already-empty history is not an error" do
      SysFlushCommand.handle(nil, nil, nil)

      assert SysFlushCommand.handle(nil, nil, nil) == "Command history cleared successfully"
      assert History.get_history() == {:ok, []}
    end
  end
end
