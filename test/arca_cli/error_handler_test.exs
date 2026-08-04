defmodule Arca.Cli.ErrorHandlerTest do
  use ExUnit.Case, async: true
  alias Arca.Cli.ErrorHandler

  describe "create_error/3" do
    test "creates an enhanced error tuple with debug info" do
      error = ErrorHandler.create_error(:command_failed, "Test error")

      assert match?({:error, :command_failed, "Test error", _debug_info}, error)

      # Extract debug info for further assertions
      {:error, _, _, debug_info} = error

      # Verify debug info structure
      assert %{timestamp: %DateTime{}, stack_trace: _, error_location: _, original_error: _} =
               debug_info
    end

    test "accepts additional debug information in options" do
      original_error = ArgumentError.exception("Invalid argument")
      error_location = "TestModule.test_function/2"

      error =
        ErrorHandler.create_error(:invalid_argument, "Invalid input",
          error_location: error_location,
          original_error: original_error
        )

      # Extract debug info
      {:error, _, _, debug_info} = error

      # Verify custom debug info was included
      assert debug_info.error_location == error_location
      assert debug_info.original_error == original_error
    end
  end

  describe "format_error/2" do
    test "formats enhanced error tuples" do
      error = ErrorHandler.create_error(:command_failed, "Test error")
      formatted = ErrorHandler.format_error(error)

      assert formatted == "error: command failed: Test error"
    end

    test "formats standard error tuples" do
      error = {:error, :invalid_argument, "Invalid value"}
      formatted = ErrorHandler.format_error(error)

      assert formatted == "error: invalid argument: Invalid value"
    end

    test "formats legacy error tuples" do
      error = {:error, "Something went wrong"}
      formatted = ErrorHandler.format_error(error)

      assert formatted == "error: Something went wrong"
    end

    test "includes debug information when debug option is true" do
      error =
        ErrorHandler.create_error(:command_failed, "Test error",
          error_location: "TestModule.test_function/2"
        )

      formatted = ErrorHandler.format_error(error, debug: true)

      # Basic assertions for debug output
      assert formatted =~ "error: command failed: Test error"
      assert formatted =~ "Debug Information:"
      assert formatted =~ "Time:"
      assert formatted =~ "Location: TestModule.test_function/2"
      assert formatted =~ "Stack trace:"
    end

    test "handles non-error values" do
      assert ErrorHandler.format_error("success") == "\"success\""
      assert ErrorHandler.format_error(42) == "42"
      assert ErrorHandler.format_error({:ok, "result"}) == "{:ok, \"result\"}"
    end
  end
end
