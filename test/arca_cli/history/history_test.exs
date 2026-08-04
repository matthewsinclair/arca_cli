defmodule Arca.Cli.History.Test do
  use ExUnit.Case, async: false
  alias Arca.Cli.History, as: History
  alias Arca.Cli.Test.Support

  doctest Arca.Cli.History

  describe "Arca.Cli.History" do
    setup do
      # Use our centralized test support function to ensure History is available
      Support.ensure_history_started()

      {:ok, %{}}
    end

    test "initial state is empty after flush" do
      History.flush_history()
      assert History.state() == %History.CliHistory{history: []}
    end

    test "push_cmd adds command to history" do
      History.flush_history()
      History.push_cmd("echo 'Hello World'")
      assert History.history() == [{0, "echo 'Hello World'"}]
    end

    test "push_cmd with non-binary command" do
      History.flush_history()
      History.push_cmd(:non_binary_command)
      assert History.history() == [{0, ":non_binary_command"}]
    end

    test "history maintains correct order" do
      History.flush_history()
      History.push_cmd("first")
      History.push_cmd("second")
      History.push_cmd("third")
      assert History.history() == [{0, "first"}, {1, "second"}, {2, "third"}]
    end

    test "hlen returns correct history length" do
      History.flush_history()
      assert History.hlen() == 0
      History.push_cmd("test")
      assert History.hlen() == 1
    end

    test "flush_history clears the history" do
      History.flush_history()
      History.push_cmd("to be flushed")
      assert History.history() == [{0, "to be flushed"}]
      History.flush_history()
      assert History.history() == []
    end

    test "state returns the current state" do
      History.flush_history()
      History.push_cmd("current state")
      # Assert on the history itself: next_index is bookkeeping for the bound,
      # not part of what callers of state/0 are asking about.
      assert History.state().history == [{0, "current state"}]
    end

    test "push_cmd trims command strings" do
      History.flush_history()
      History.push_cmd("  spaced out command  ")
      assert History.history() == [{0, "spaced out command"}]
    end

    test "concurrent command pushes" do
      History.flush_history()
      Task.async(fn -> History.push_cmd("cmd1") end)
      Task.async(fn -> History.push_cmd("cmd2") end)
      Task.async(fn -> History.push_cmd("cmd3") end)
      # Give time for tasks to finish
      :timer.sleep(100)
      assert length(History.history()) == 3
    end

    test "push_cmd with list of arguments (CLI mode)" do
      History.flush_history()
      History.push_cmd(["st", "new", "Test Title"])
      assert History.history() == [{0, "st new \"Test Title\""}]
    end

    test "push_cmd with list containing options" do
      History.flush_history()
      History.push_cmd(["st", "new", "Test Title", "--priority=high"])
      assert History.history() == [{0, "st new \"Test Title\" --priority=high"}]
    end

    test "push_cmd with list containing multiple quoted arguments" do
      History.flush_history()
      History.push_cmd(["st", "new", "First Title", "--desc", "Long description here"])

      assert History.history() == [
               {0, "st new \"First Title\" --desc \"Long description here\""}
             ]
    end

    test "push_cmd with list containing arguments without spaces" do
      History.flush_history()
      History.push_cmd(["st", "list", "--status=active"])
      assert History.history() == [{0, "st list --status=active"}]
    end

    test "push_cmd with empty list" do
      History.flush_history()
      History.push_cmd([])
      assert History.history() == [{0, ""}]
    end
  end
end
