defmodule Arca.Cli.ErrorHandlingTest do
  use ExUnit.Case, async: false
  import ExUnit.CaptureIO
  alias Arca.Cli.Test.Support

  setup do
    # Store original debug mode
    original_debug = Application.get_env(:arca_cli, :debug_mode)

    # Reset after the test
    on_exit(fn -> Support.restore_app_env(:arca_cli, :debug_mode, original_debug) end)

    :ok
  end

  describe "with debug mode disabled" do
    setup do
      Application.put_env(:arca_cli, :debug_mode, false)
      :ok
    end

    test "handles raised exceptions with basic info" do
      output =
        capture_io(fn ->
          Arca.Cli.main(["cli.error", "raise"])
        end)

      # Should show basic error message
      assert output =~
               "Error executing command cli.error: This is a test exception from CliErrorCommand"

      # Should not show debug info
      refute output =~ "Debug Information:"
      refute output =~ "Stack trace:"
    end

    test "handles standard error tuples" do
      output =
        capture_io(fn ->
          Arca.Cli.main(["cli.error", "standard"])
        end)

      # Should show formatted error
      assert output =~ "Error (invalid_argument): This is a standard error tuple test"
      # Should not show debug info
      refute output =~ "Debug Information:"
    end

    test "handles legacy error tuples" do
      output =
        capture_io(fn ->
          Arca.Cli.main(["cli.error", "legacy"])
        end)

      # Should show formatted error
      assert output =~ "This is a legacy error tuple test"
      # Should not show debug info
      refute output =~ "Debug Information:"
    end
  end

  describe "with debug mode enabled" do
    setup do
      Application.put_env(:arca_cli, :debug_mode, true)
      :ok
    end

    test "handles raised exceptions with detailed debug info" do
      output =
        capture_io(fn ->
          Arca.Cli.main(["cli.error", "raise"])
        end)

      # Should show basic error message
      assert output =~
               "Error (command_failed): Error executing command cli.error: This is a test exception from CliErrorCommand"

      # Should show debug info
      assert output =~ "Debug Information:"
      assert output =~ "Stack trace:"
      assert output =~ "Time:"
      assert output =~ "Original error:"
    end

    test "handles standard error tuples with debug info" do
      output =
        capture_io(fn ->
          Arca.Cli.main(["cli.error", "standard"])
        end)

      # Should show formatted error with debug info
      assert output =~ "Error (invalid_argument): This is a standard error tuple test"
      assert output =~ "Debug Information:"
      assert output =~ "Location:"
    end

    test "successful responses are unaffected by debug mode" do
      output =
        capture_io(fn ->
          Arca.Cli.main(["cli.error", "success"])
        end)

      # Should just show the success message
      assert output == "Success: No error occurred\n"
    end
  end

  test "errors are not displayed twice" do
    Application.put_env(:arca_cli, :debug_mode, false)

    output =
      capture_io(fn ->
        Arca.Cli.main(["cli.error", "raise"])
      end)

    # Count occurrences of the error message
    error_text =
      "Error executing command cli.error: This is a test exception from CliErrorCommand"

    count =
      output
      |> String.split(error_text)
      |> length
      # Subtract 1 because split returns n+1 parts for n occurrences
      |> Kernel.-(1)

    # Should appear exactly once
    assert count == 1, "Error message was displayed #{count} times, expected once"
  end
end
