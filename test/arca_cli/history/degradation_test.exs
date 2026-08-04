defmodule Arca.Cli.History.DegradationTest do
  @moduledoc """
  Covers History's behaviour when its process is not running (finding A5).

  Every client function wrapped `GenServer.call/2` in `try/rescue` and documented
  a graceful `{:error, :history_not_available, _}` return. A call to a dead or
  absent process **exits** the caller rather than raising, and `rescue` cannot
  catch an exit -- so the degradation never happened and the caller died instead.
  The REPL prompt asks for the history length on every redraw, so a History crash
  took the whole session down with it.

  These tests run with History deliberately stopped. They are `async: false`
  because they manipulate a named global process.
  """
  use ExUnit.Case, async: false

  alias Arca.Cli.History

  setup do
    # Unregister the name rather than killing the process.
    #
    # History is supervised in the test suite -- the application starts before
    # test_helper.exs runs, so the `Mix.env() == :test` branch guarding the
    # supervisor never fires -- and a permanent child is restarted the moment it
    # stops. Killing it therefore raced the supervisor and made this whole module
    # order-dependent. Unregistering produces the identical `:noproc` exit from
    # `GenServer.call/2` with no race and nothing for the supervisor to notice.
    history = Process.whereis(History)
    Process.unregister(History)
    on_exit(fn -> Process.register(history, History) end)

    :ok
  end

  describe "History is down" do
    test "invariant: the process really is absent for these tests" do
      assert Process.whereis(History) == nil
    end

    test "failure: get_state/0 returns the documented error rather than exiting" do
      assert {:error, :history_not_available, message} = History.get_state()
      assert is_binary(message)
    end

    test "failure: get_history/0 returns the documented error rather than exiting" do
      assert {:error, :history_not_available, message} = History.get_history()
      assert is_binary(message)
    end

    test "failure: push_cmd/1 returns the documented error rather than exiting" do
      assert {:error, :history_operation_failed, message} = History.push_cmd("about")
      assert is_binary(message)
    end

    test "failure: get_history_length/0 returns the documented error rather than exiting" do
      assert {:error, :history_operation_failed, message} = History.get_history_length()
      assert is_binary(message)
    end

    test "failure: flush_history/0 returns the documented error rather than exiting" do
      assert {:error, :history_operation_failed, message} = History.flush_history()
      assert is_binary(message)
    end

    test "invariant: the caller survives every one of those calls" do
      # The point of the finding: these used to take the calling process with
      # them. Reaching this assertion at all is the proof.
      History.get_state()
      History.get_history()
      History.push_cmd("about")
      History.get_history_length()
      History.flush_history()

      assert Process.alive?(self())
    end

    test "success: get_all/0 degrades to an empty list" do
      assert History.get_all() == []
    end
  end
end
