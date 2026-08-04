defmodule Arca.Cli.History.BoundedTest do
  @moduledoc """
  History must not grow without limit.

  A long-running REPL session accumulated every command it had ever run. The
  bound is `config :arca_cli, history_size: n`, defaulting to 100.
  """
  use ExUnit.Case, async: false

  alias Arca.Cli.History
  alias Arca.Cli.Test.Support

  setup do
    previous_size = Application.get_env(:arca_cli, :history_size)
    Support.ensure_history_started()
    History.flush_history()

    on_exit(fn ->
      Support.restore_app_env(:arca_cli, :history_size, previous_size)
      History.flush_history()
    end)

    :ok
  end

  describe "history is bounded" do
    test "success: the default bound is 100" do
      Application.delete_env(:arca_cli, :history_size)

      assert History.history_size() == 100
    end

    test "invariant: history never exceeds the configured size" do
      Application.put_env(:arca_cli, :history_size, 5)

      for n <- 1..20, do: History.push_cmd("command #{n}")

      {:ok, history} = History.get_history()
      assert length(history) == 5
    end

    test "success: the entries kept are the most recent ones" do
      Application.put_env(:arca_cli, :history_size, 3)

      for n <- 1..10, do: History.push_cmd("command #{n}")

      {:ok, history} = History.get_history()

      assert Enum.map(history, fn {_index, cmd} -> cmd end) ==
               ["command 8", "command 9", "command 10"]
    end

    test "invariant: indices stay unique once the bound starts discarding entries" do
      # The index used to be derived from the list length, which stops growing
      # once history is full -- so every later command reused the same index and
      # `cli.redo` could no longer address them apart.
      Application.put_env(:arca_cli, :history_size, 3)

      for n <- 1..10, do: History.push_cmd("command #{n}")

      {:ok, history} = History.get_history()
      indices = Enum.map(history, fn {index, _cmd} -> index end)

      assert indices == Enum.uniq(indices)
      assert indices == [7, 8, 9]
    end

    test "invariant: an invalid configured size falls back to the default" do
      Application.put_env(:arca_cli, :history_size, 0)

      assert History.history_size() == 100
    end
  end
end
