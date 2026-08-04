defmodule Arca.Cli.DisplayRegressionTest do
  @moduledoc """
  Guards the display half of the dispatch contract.

  Adding the outcome channel (issue 0001) had to change exit codes without
  changing a single byte of what the user sees. That was established against
  0.4.3 by capturing this corpus from both checkouts and diffing them; these
  tests are the standing guard that keeps it true.

  Each case pins both halves of the dispatch result: the outcome the CLI
  reports, and the exact text it prints for it.

  Not covered here, deliberately: `settings.get`/`cfg.get`, `cli.script` and
  `cli.redo` still return their failure as a plain string and so report `:ok`.
  That is a separate catalogued defect (see ST0011 finding A13) fixed in a
  later work package; pinning the wrong outcome here would enshrine it.
  """
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Arca.Cli.Test.Support

  # These cases pin exact error text, and debug mode appends a debug block to it.
  # Pin the setting rather than inheriting whatever ran before: a test that asserts
  # exact output must own every input that shapes it.
  setup do
    original_app = Application.get_env(:arca_cli, :debug_mode)
    original_setting = Support.setting_value("debug_mode")

    Application.put_env(:arca_cli, :debug_mode, false)

    on_exit(fn ->
      Support.restore_app_env(:arca_cli, :debug_mode, original_app)
      Support.restore_setting("debug_mode", original_setting)
    end)

    :ok
  end

  # Run the CLI in-process, returning both halves of what the user experiences.
  @spec run_cli([String.t()]) :: {Arca.Cli.outcome(), String.t()}
  defp run_cli(argv) do
    {outcome, io} = with_io(fn -> Arca.Cli.run(argv) end)
    {outcome, String.trim(io)}
  end

  describe "successful commands" do
    test "success: a plain string command prints its output and reports :ok" do
      assert run_cli(["cli.error", "success"]) == {:ok, "Success: No error occurred"}
    end
  end

  describe "error tuple paths" do
    test "failure: a standard error tuple keeps its typed message" do
      assert run_cli(["cli.error", "standard"]) ==
               {:error, "Error (invalid_argument): This is a standard error tuple test"}
    end

    test "failure: a legacy error tuple keeps its typed message" do
      assert run_cli(["cli.error", "legacy"]) ==
               {:error, "Error (command_failed): This is a legacy error tuple test"}
    end
  end

  describe "parse and lookup failure paths" do
    test "failure: an unknown command keeps its message" do
      assert run_cli(["nosuchcommand"]) == {:error, "error: Unknown command: nosuchcommand"}
    end

    test "failure: help for an unknown command keeps its message" do
      assert run_cli(["help", "nosuchcommand"]) ==
               {:error, "error: unknown command: nosuchcommand"}
    end

    test "failure: a missing required argument keeps its message" do
      assert run_cli(["settings.get"]) ==
               {:error, "error: settings.get: missing required arguments: SETTING_ID"}
    end
  end
end
