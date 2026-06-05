defmodule Arca.Cli.ErrorHandlerTest do
  use ExUnit.Case, async: true
  alias Arca.Cli.ErrorHandler

  # Import the macro for testing
  require Arca.Cli.ErrorHandler

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

      assert formatted == "Error (command_failed): Test error"
    end

    test "formats standard error tuples" do
      error = {:error, :invalid_argument, "Invalid value"}
      formatted = ErrorHandler.format_error(error)

      assert formatted == "Error (invalid_argument): Invalid value"
    end

    test "formats legacy error tuples" do
      error = {:error, "Something went wrong"}
      formatted = ErrorHandler.format_error(error)

      assert formatted == "Error (unknown_error): Something went wrong"
    end

    test "includes debug information when debug option is true" do
      error =
        ErrorHandler.create_error(:command_failed, "Test error",
          error_location: "TestModule.test_function/2"
        )

      formatted = ErrorHandler.format_error(error, debug: true)

      # Basic assertions for debug output
      assert formatted =~ "Error (command_failed): Test error"
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

  describe "normalize_error/2" do
    test "converts standard error to enhanced error" do
      standard_error = {:error, :command_failed, "Test error"}
      enhanced = ErrorHandler.normalize_error(standard_error)

      assert match?({:error, :command_failed, "Test error", _debug_info}, enhanced)
    end

    test "converts legacy error to enhanced error" do
      legacy_error = {:error, "Test error"}
      enhanced = ErrorHandler.normalize_error(legacy_error)

      assert match?({:error, :unknown_error, "Test error", _debug_info}, enhanced)
    end

    test "passes through enhanced errors unchanged" do
      original = ErrorHandler.create_error(:invalid_argument, "Test error")
      result = ErrorHandler.normalize_error(original)

      assert result == original
    end

    test "passes through non-error values unchanged" do
      assert ErrorHandler.normalize_error("success") == "success"
      assert ErrorHandler.normalize_error({:ok, "result"}) == {:ok, "result"}
    end
  end

  describe "to_standard_error/1" do
    test "converts enhanced error to standard error" do
      enhanced = ErrorHandler.create_error(:command_failed, "Test error")
      standard = ErrorHandler.to_standard_error(enhanced)

      assert standard == {:error, :command_failed, "Test error"}
    end

    test "passes through standard errors unchanged" do
      standard = {:error, :command_failed, "Test error"}
      result = ErrorHandler.to_standard_error(standard)

      assert result == standard
    end

    test "passes through non-error values unchanged" do
      assert ErrorHandler.to_standard_error("success") == "success"
      assert ErrorHandler.to_standard_error({:ok, "result"}) == {:ok, "result"}
    end
  end

  describe "to_legacy_error/1" do
    test "converts enhanced error to legacy error" do
      enhanced = ErrorHandler.create_error(:command_failed, "Test error")
      legacy = ErrorHandler.to_legacy_error(enhanced)

      assert legacy == {:error, "Test error"}
    end

    test "converts standard error to legacy error" do
      standard = {:error, :command_failed, "Test error"}
      legacy = ErrorHandler.to_legacy_error(standard)

      assert legacy == {:error, "Test error"}
    end

    test "passes through legacy errors unchanged" do
      legacy = {:error, "Test error"}
      result = ErrorHandler.to_legacy_error(legacy)

      assert result == legacy
    end

    test "passes through non-error values unchanged" do
      assert ErrorHandler.to_legacy_error("success") == "success"
      assert ErrorHandler.to_legacy_error({:ok, "result"}) == {:ok, "result"}
    end
  end

  describe "create_error_with_location/3" do
    test "creates an error with automatic location information" do
      # Use the macro
      error = ErrorHandler.create_error_with_location(:validation_error, "Test error")

      # Verify the error structure
      assert match?(
               {:error, :validation_error, "Test error", %{error_location: _location}},
               error
             )

      # Extract the debug info to verify contents
      {:error, _, _, debug_info} = error
      assert debug_info.error_location =~ "Arca.Cli.ErrorHandlerTest"
    end

    test "respects additional options when creating error" do
      # Use the macro with extra options
      original_error = ArgumentError.exception("Invalid config")

      error =
        ErrorHandler.create_error_with_location(
          :config_error,
          "Configuration error",
          original_error: original_error
        )

      # Verify error structure with extra options
      assert match?({:error, :config_error, "Configuration error", %{}}, error)

      # Extract debug info to check original_error was included
      {:error, _, _, debug_info} = error
      assert debug_info.error_location =~ "Arca.Cli.ErrorHandlerTest"
      assert debug_info.original_error == original_error
    end
  end

  describe "create_and_format_error_with_location/3" do
    test "creates and formats an error with location information" do
      # Use the macro
      formatted =
        ErrorHandler.create_and_format_error_with_location(:validation_error, "Test error")

      # Verify the formatted output contains the error info
      assert formatted =~ "Error (validation_error): Test error"

      # Would automatically include the current module and function as location
      # but we can't easily test that in a static test
    end

    test "respects additional options" do
      # Use the macro with extra options
      formatted =
        ErrorHandler.create_and_format_error_with_location(
          :config_error,
          "Configuration error",
          original_error: ArgumentError.exception("Invalid config")
        )

      assert formatted =~ "Error (config_error): Configuration error"

      # Test with debug mode to see if original_error was properly included
      debug_formatted =
        ErrorHandler.create_error(
          :config_error,
          "Configuration error",
          original_error: ArgumentError.exception("Invalid config")
        )
        |> ErrorHandler.format_error(debug: true)

      assert debug_formatted =~ "Original error: %ArgumentError{message: \"Invalid config\"}"
    end
  end

  describe "err_cloc/3 (shorthand for create_error_with_location)" do
    test "provides a shorthand for create_error_with_location" do
      # Use the shorthand macro
      error = ErrorHandler.err_cloc(:validation_error, "Test error")

      # Verify the error structure is the same as with the long form
      assert match?(
               {:error, :validation_error, "Test error", %{error_location: _location}},
               error
             )

      # Extract the debug info to verify contents
      {:error, _, _, debug_info} = error
      assert debug_info.error_location =~ "Arca.Cli.ErrorHandlerTest"
    end

    test "accepts options and passes them through" do
      original_error = ArgumentError.exception("Invalid config")

      error =
        ErrorHandler.err_cloc(
          :config_error,
          "Configuration error",
          original_error: original_error
        )

      # Check that options were passed through correctly
      {:error, _, _, debug_info} = error
      assert debug_info.error_location =~ "Arca.Cli.ErrorHandlerTest"
      assert debug_info.original_error == original_error
    end
  end

  describe "err_cfloc/3 (shorthand for create_and_format_error_with_location)" do
    test "provides a shorthand for create_and_format_error_with_location" do
      # Use the shorthand macro
      formatted = ErrorHandler.err_cfloc(:validation_error, "Test error")

      # Verify the formatted output is the same as with the long form
      assert formatted =~ "Error (validation_error): Test error"
    end

    test "accepts options and passes them through" do
      original_error = ArgumentError.exception("Invalid config")

      formatted =
        ErrorHandler.err_cfloc(
          :config_error,
          "Configuration error",
          original_error: original_error
        )

      # Verify it works the same as the long form
      assert formatted =~ "Error (config_error): Configuration error"

      # Test with debug output to see if the options were passed through
      debug_formatted =
        ErrorHandler.create_error(
          :config_error,
          "Configuration error",
          original_error: ArgumentError.exception("Invalid config")
        )
        |> ErrorHandler.format_error(debug: true)

      assert debug_formatted =~ "Original error: %ArgumentError{message: \"Invalid config\"}"
    end
  end
end
