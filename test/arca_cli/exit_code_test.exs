defmodule Arca.Cli.ExitCodeTest do
  @moduledoc """
  Proves the exit-code contract at a real OS process boundary (issue 0001).

  These tests assert the process exit status, not a return value: the defect
  they guard against was a CLI that reported failure on stdout while exiting 0,
  so shells and CI could not branch on it. Only a real subprocess can show that.

  The subprocess is `mix run -e`, so the suite does not depend on the escript
  build artifact being present. Exit status is set by `Arca.Cli.main/1` and is
  independent of Mix env; escript evidence is recorded separately in the steel
  thread's probe re-run.
  """
  use ExUnit.Case, async: true

  # Run the CLI in a separate OS process and return only its exit status.
  @spec exit_status([String.t()]) :: non_neg_integer()
  defp exit_status(argv) do
    {_output, status} =
      System.cmd("mix", ["run", "-e", "Arca.Cli.main(#{inspect(argv)})"],
        stderr_to_stdout: true
      )

    status
  end

  describe "failing commands" do
    test "failure: a command returning a standard error tuple exits 1" do
      assert exit_status(["cli.error", "standard"]) == 1
    end

    test "failure: a command returning a legacy error tuple exits 1" do
      assert exit_status(["cli.error", "legacy"]) == 1
    end

    test "failure: a command raising an exception exits 1" do
      assert exit_status(["cli.error", "raise"]) == 1
    end

    test "failure: an unknown command exits 1" do
      assert exit_status(["nosuchcommand"]) == 1
    end

    test "failure: help for an unknown command exits 1" do
      assert exit_status(["help", "nosuchcommand"]) == 1
    end
  end

  describe "succeeding commands" do
    test "success: a command returning output exits 0" do
      assert exit_status(["cli.error", "success"]) == 0
    end

    test "success: about exits 0" do
      assert exit_status(["about"]) == 0
    end

    test "success: --help exits 0" do
      assert exit_status(["--help"]) == 0
    end
  end

  describe "context status drives exit status" do
    test "failure: Ctx.complete(:error) exits 1" do
      assert exit_status(["cli.error", "ctx"]) == 1
    end

    test "success: Ctx.complete(:warning) exits 0" do
      assert exit_status(["cli.error", "warning"]) == 0
    end
  end
end
