defmodule Arca.Cli.Eg.EgExitCodeTest do
  @moduledoc """
  Proves the downstream contract: a project whose escript `main_module` does
  nothing but delegate to `Arca.Cli.main/1` inherits correct exit codes from a
  dependency bump alone, with no code change of its own.

  This is why the halt lives in `main/1` rather than in a separate entry point:
  downstream escripts already point at `main/1`.

  The wrapper under test is `test/support/downstream_escript.exs`, run as a
  real OS process so the exit status is the one a shell would observe.
  """
  use ExUnit.Case, async: true

  # `mix test` has already compiled this build, and every child here inherits
  # MIX_ENV=test from it. Without these flags each child re-verifies that build
  # while holding the global build-directory lock, so concurrent subprocess tests
  # queue behind one another and the run prints "Waiting for lock on the build
  # directory". The work being skipped is work the parent just did.
  @mix_run ["run", "--no-compile", "--no-deps-check"]

  @wrapper "test/support/downstream_escript.exs"

  # Run the downstream wrapper in a separate OS process, returning its exit status.
  @spec wrapper_exit_status([String.t()]) :: non_neg_integer()
  defp wrapper_exit_status(argv) do
    {_output, status} =
      System.cmd("mix", @mix_run ++ [@wrapper | argv], stderr_to_stdout: true)

    status
  end

  describe "downstream wrapper exit codes" do
    test "failure: a failing command exits 1 through the wrapper" do
      assert wrapper_exit_status(["cli.error", "standard"]) == 1
    end

    test "failure: an unknown command exits 1 through the wrapper" do
      assert wrapper_exit_status(["nosuchcommand"]) == 1
    end

    test "success: a succeeding command exits 0 through the wrapper" do
      assert wrapper_exit_status(["cli.error", "success"]) == 0
    end
  end
end
