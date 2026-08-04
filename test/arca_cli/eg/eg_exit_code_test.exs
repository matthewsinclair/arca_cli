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
  # `async: false` because this module still spawns a `mix run` child, which takes
  # the GLOBAL build-directory lock -- shared global state, which is what an async
  # opt-out is for. The escript-based tests take no lock and stay async; this
  # module cannot use the escript because what it asks is not the CLI.
  use ExUnit.Case, async: false

  alias Arca.Cli.Test.Subprocess

  @wrapper "test/support/downstream_escript.exs"

  # Run the downstream wrapper in a separate OS process, returning its exit status.
  @spec wrapper_exit_status([String.t()]) :: non_neg_integer()
  defp wrapper_exit_status(argv) do
    Subprocess.script(@wrapper, argv, stderr_to_stdout: true) |> elem(1)
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
