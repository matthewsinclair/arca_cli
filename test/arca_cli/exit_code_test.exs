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

  # `mix test` has already compiled this build, and every child here inherits
  # MIX_ENV=test from it. Without these flags each child re-verifies that build
  # while holding the global build-directory lock, so concurrent subprocess tests
  # queue behind one another and the run prints "Waiting for lock on the build
  # directory". The work being skipped is work the parent just did.
  @mix_run ["run", "--no-compile", "--no-deps-check"]

  # Run the CLI in a separate OS process and return only its exit status.
  @spec exit_status([String.t()]) :: non_neg_integer()
  defp exit_status(argv) do
    {_output, status} =
      System.cmd("mix", @mix_run ++ ["-e", "Arca.Cli.main(#{inspect(argv)})"],
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

  describe "commands that report failure as a plain string (finding A13)" do
    # These four printed a failure and returned it as ordinary output, which the
    # dispatch layer could only read as success. Fixing the plumbing in WP-01 did
    # nothing for them: there was no outcome to propagate, because the command had
    # already thrown it away by turning it into a display string.

    test "failure: a setting that does not exist exits 1" do
      assert exit_status(["settings.get", "nosuchkey"]) == 1
    end

    test "failure: a config key that does not exist exits 1" do
      assert exit_status(["cfg.get", "nosuchkey"]) == 1
    end

    test "failure: a redo index outside the history exits 1" do
      assert exit_status(["cli.redo", "999"]) == 1
    end

    test "failure: a script that cannot be read exits 1" do
      assert exit_status(["cli.script", "/nonexistent"]) == 1
    end

    test "failure: an OS command that fails exits 1" do
      assert exit_status(["sys.cmd", "false"]) == 1
    end

    test "success: a setting that does exist still exits 0" do
      assert exit_status(["settings.get", "id"]) == 0
    end
  end
end
