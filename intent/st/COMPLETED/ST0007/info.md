---
verblock: "17 Apr 2025:v0.2: Matthew Sinclair - Updated with as-built implementation
15 Apr 2025:v0.1: Matthew Sinclair - Initial version"
stp_version: 1.0.0
status: COMPLETED
created: 20250415
completed: 20250417
---

# ST0007: Improved CLI and REPL Error Handling

## Summary

Improve error handling in Arca CLI and REPL to address issues where errors bubble up through the command chain without proper handling. Currently, these errors result in uninformative and duplicate error messages, making debugging difficult. This steel thread provides a comprehensive solution with enhanced error reporting, debug mode capability, and consistent error handling across the CLI application.

## Design

### Current Issues

1. **Uninformative Error Messages**: When an unhandled error bubbles up through the command chain, users see only basic error messages without context or debug information.

2. **Duplicate Error Messages**: In some error scenarios, the same error message is displayed twice due to multiple error handling paths.

3. **Inconsistent Error Handling**: The codebase transitions between legacy `{:error, reason}` and newer `{:error, error_type, reason}` formats.

4. **Lost Debug Information**: Exception details are logged but not made available to the user for troubleshooting.

### Proposed Solution

The solution introduces a centralized error handling approach with enhanced error information and an optional debug mode:

1. **Centralized Error Handler Module**: Create `Arca.Cli.ErrorHandler` to standardize error handling across the application.

2. **Enhanced Error Tuples**: Extend error tuples to include debug information such as stack traces and error context.

3. **Debug Mode Command**: Add a new `cli.debug` command to toggle detailed error information for users.

4. **Unified Error Formatting**: Consolidate error formatting logic to eliminate duplicate messages.

5. **Improved Exception Handling**: Preserve stack traces and context when handling exceptions.

### Components

#### 1. ErrorHandler Module

```elixir
defmodule Arca.Cli.ErrorHandler do
  @moduledoc """
  Central module for handling and formatting errors in Arca CLI.
  """

  @type error_type :: Arca.Cli.error_type() | Arca.Cli.Command.BaseCommand.error_type()

  @typedoc "Debug information attached to errors"
  @type debug_info :: %{
    stack_trace: list(),
    error_location: String.t(),
    original_error: any(),
    timestamp: DateTime.t()
  }

  @typedoc "Enhanced error tuple with debug information"
  @type enhanced_error :: {:error, error_type(), String.t(), debug_info() | nil}

  @doc """
  Create an enhanced error with debug information.
  """
  @spec create_error(error_type(), String.t(), Keyword.t()) :: enhanced_error()
  def create_error(error_type, reason, opts \\ []) do
    stack_trace = Keyword.get(opts, :stack_trace, nil) || Process.info(self(), :current_stacktrace)
    error_location = Keyword.get(opts, :error_location, nil)
    original_error = Keyword.get(opts, :original_error, nil)

    debug_info = %{
      stack_trace: stack_trace,
      error_location: error_location,
      original_error: original_error,
      timestamp: DateTime.utc_now()
    }

    {:error, error_type, reason, debug_info}
  end

  @doc """
  Format errors for display with optional debug information.
  """
  @spec format_error(enhanced_error() | any(), Keyword.t()) :: String.t()
  def format_error({:error, error_type, reason, debug_info}, opts \\ []) do
    include_debug = Keyword.get(opts, :debug, false)

    base_error = "Error (#{error_type}): #{reason}"

    if include_debug && debug_info do
      base_error <> "\n" <> format_debug_info(debug_info)
    else
      base_error
    end
  end

  # Handle legacy error formats
  def format_error({:error, error_type, reason}, opts), do: format_error({:error, error_type, reason, nil}, opts)
  def format_error({:error, reason}, opts), do: format_error({:error, :unknown_error, reason, nil}, opts)

  # Pass through non-error values unchanged
  def format_error(value, _), do: value

  defp format_debug_info(debug_info) do
    # Format debug information in a structured, readable way
    [
      "Debug Information:",
      "  Time: #{debug_info.timestamp}",
      if debug_info.error_location, do: "  Location: #{debug_info.error_location}",
      if debug_info.original_error, do: "  Original error: #{inspect(debug_info.original_error)}",
      "  Stack trace:",
      format_stack_trace(debug_info.stack_trace)
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.join("\n")
  end

  defp format_stack_trace(nil), do: "    <not available>"
  defp format_stack_trace(stack_trace) do
    Enum.map_join(stack_trace, "\n", fn {module, function, arity, location} ->
      file = Keyword.get(location, :file, "<unknown>")
      line = Keyword.get(location, :line, "<unknown>")
      "    #{inspect(module)}.#{function}/#{arity} (#{file}:#{line})"
    end)
  end
end
```

#### 2. Debug Mode Command

```elixir
defmodule Arca.Cli.Commands.CliDebugCommand do
  use Arca.Cli.Command.BaseCommand

  config :"cli.debug",
    name: "cli.debug",
    about: "Show or toggle debug mode for detailed error information",
    args: [
      toggle: [
        value_name: "on|off",
        help: "Turn debug mode on or off",
        required: false
      ]
    ]

  @impl true
  def handle(args, _settings, _optimus) do
    toggle = args.args.toggle

    current = Application.get_env(:arca_cli, :debug_mode, false)

    case toggle do
      nil ->
        "Debug mode is currently #{if current, do: "ON", else: "OFF"}"

      "on" ->
        Application.put_env(:arca_cli, :debug_mode, true)
        "Debug mode is now ON"

      "off" ->
        Application.put_env(:arca_cli, :debug_mode, false)
        "Debug mode is now OFF"

      _ ->
        {:error, :invalid_argument, "Invalid value '#{toggle}'. Use 'on' or 'off'."}
    end
  end
end
```

#### 3. Enhanced execute_command Function

Update the error handling in the command execution path to capture and preserve error details:

```elixir
@spec execute_command(atom(), map(), map(), term(), module()) ::
        result(String.t() | [String.t()])
def execute_command(cmd, args, settings, optimus, handler) do
  try do
    # Use the centralized help system to check if help should be shown
    if Arca.Cli.Help.should_show_help?(cmd, args, handler) do
      # Show help for this command using the centralized help system
      {:ok, Arca.Cli.Help.show(cmd, args, optimus)}
    else
      # Normal command execution with enhanced error handling
      result = handler.handle(args, settings, optimus)

      # Normalize error formats using the central ErrorHandler
      case result do
        {:error, reason} when is_binary(reason) ->
          # Convert legacy error format to enhanced format
          ErrorHandler.create_error(:command_failed, reason, error_location: "#{handler}.handle/3")

        {:error, error_type, reason} ->
          # Convert standard error format to enhanced format
          ErrorHandler.create_error(error_type, reason, error_location: "#{handler}.handle/3")

        {:error, error_type, reason, _debug_info} = enhanced_error ->
          # Already using enhanced format, pass through
          enhanced_error

        other ->
          # All other returns (string, list, etc.) considered success
          {:ok, other}
      end
    end
  rescue
    e ->
      stacktrace = System.stacktrace()
      Logger.error("Error executing command #{cmd}: #{inspect(e)}\n#{Exception.format_stacktrace(stacktrace)}")

      # Create enhanced error with exception details
      ErrorHandler.create_error(
        :command_failed,
        "Error executing command #{cmd}: #{Exception.message(e)}",
        original_error: e,
        stack_trace: stacktrace,
        error_location: "execute_command/5"
      )
  end
end
```

#### 4. Updated REPL Error Handling

Modify the REPL error handling to use the centralized formatter:

```elixir
@spec print_error(any()) :: :ok
def print_error(error_message) do
  # Use the central error formatter with debug flag
  debug_enabled = Application.get_env(:arca_cli, :debug_mode, false)
  formatted = Arca.Cli.ErrorHandler.format_error(error_message, debug: debug_enabled)

  # Print once without duplicate formatting
  IO.puts(formatted)
  :ok
end
```

## Implementation Details

The improved error handling system has been implemented with the following components:

### 1. ErrorHandler Module

The `Arca.Cli.ErrorHandler` module serves as the central hub for error handling, providing functions to create, format, and normalize errors:

```elixir
defmodule Arca.Cli.ErrorHandler do
  @moduledoc """
  Central module for handling and formatting errors in Arca CLI.

  This module provides standardized functions for creating, transforming, and
  formatting error tuples. It handles both legacy error formats for backward
  compatibility and enhanced formats that include debug information.
  """

  require Logger

  @typedoc """
  Types of errors that can occur in CLI operations.
  Combines error types from Arca.Cli and BaseCommand.
  """
  @type error_type ::
          :command_not_found
          | :command_failed
          | :invalid_argument
          | :config_error
          | :file_not_found
          | :file_not_readable
          | :file_not_writable
          | :decode_error
          | :encode_error
          | :unknown_error
          # From Arca.Cli.Command.BaseCommand
          | :validation_error
          | :command_mismatch
          | :not_implemented
          | :invalid_module_name
          | :invalid_command_name
          | :help_requested

  @typedoc """
  Debug information attached to errors for better troubleshooting.
  """
  @type debug_info :: %{
          stack_trace: list() | nil,
          error_location: String.t() | nil,
          original_error: any() | nil,
          timestamp: DateTime.t()
        }

  @typedoc """
  Enhanced error tuple with additional debug information.
  """
  @type enhanced_error :: {:error, error_type(), String.t(), debug_info() | nil}

  @doc """
  Create an enhanced error tuple with debug information.

  ## Parameters
    - error_type: The type of error (atom)
    - reason: Description or data about the error
    - opts: Options for additional debug information
      - :stack_trace - Stack trace to include (defaults to current stacktrace)
      - :error_location - String describing where error occurred
      - :original_error - Original exception or error value

  ## Returns
    - An enhanced error tuple of the form {:error, error_type, reason, debug_info}
  """
  @spec create_error(error_type(), String.t(), Keyword.t()) :: enhanced_error()
  def create_error(error_type, reason, opts \\ []) do
    # Get stack trace with fallback to current stacktrace
    stack_trace = Keyword.get(opts, :stack_trace)

    # Get other debug information from options
    error_location = Keyword.get(opts, :error_location)
    original_error = Keyword.get(opts, :original_error)

    # Build debug info map
    debug_info = %{
      stack_trace: stack_trace,
      error_location: error_location,
      original_error: original_error,
      timestamp: DateTime.utc_now()
    }

    {:error, error_type, reason, debug_info}
  end

  @doc """
  Format errors for display, optionally including debug information.

  This function handles various error tuple formats for compatibility:
  - Enhanced error tuples: {:error, error_type, reason, debug_info}
  - Standard error tuples: {:error, error_type, reason}
  - Legacy error tuples: {:error, reason}

  ## Parameters
    - error: The error to format (any format)
    - opts: Formatting options
      - :debug - Boolean flag to include debug information (default: false)

  ## Returns
    - Formatted error string with optional debug information
  """
  @spec format_error(
          enhanced_error() | {:error, error_type(), String.t()} | {:error, String.t()} | any(),
          Keyword.t()
        ) :: String.t()
  def format_error(error, opts \\ [])

  def format_error({:error, error_type, reason, debug_info}, opts) do
    # Check if debug mode is enabled
    include_debug = Keyword.get(opts, :debug, false)

    # Format the base error message
    base_error = "Error (#{error_type}): #{reason}"

    # Add debug information if enabled and available
    if include_debug && debug_info do
      base_error <> "\n" <> format_debug_info(debug_info)
    else
      base_error
    end
  end

  # Handle standard error tuples (without debug info)
  def format_error({:error, error_type, reason}, opts) do
    format_error({:error, error_type, reason, nil}, opts)
  end

  # Handle legacy error tuples (just reason)
  def format_error({:error, reason}, opts) when is_binary(reason) do
    format_error({:error, :unknown_error, reason, nil}, opts)
  end

  # Pass through non-error values unchanged
  def format_error(value, _opts) do
    inspect(value)
  end

  # Format debug information in a structured, readable way
  @spec format_debug_info(debug_info()) :: String.t()
  defp format_debug_info(debug_info) do
    # Build lines of debug information, filtering out nil values
    debug_lines = [
      "Debug Information:",
      "  Time: #{DateTime.to_string(debug_info.timestamp)}",
      format_location(debug_info.error_location),
      format_original_error(debug_info.original_error),
      "  Stack trace:",
      format_stack_trace(debug_info.stack_trace)
    ]

    # Join non-nil lines with newlines
    debug_lines
    |> Enum.reject(&is_nil/1)
    |> Enum.join("\n")
  end

  # Format helpers for debug information components
  defp format_location(nil), do: nil
  defp format_location(location), do: "  Location: #{location}"

  defp format_original_error(nil), do: nil
  defp format_original_error(error), do: "  Original error: #{inspect(error)}"

  defp format_stack_trace(nil), do: "    <not available>"
  defp format_stack_trace([]), do: "    <empty stack trace>"

  defp format_stack_trace(stack_trace) do
    stack_trace
    # Limit to reasonable number of frames
    |> Enum.take(10)
    |> Enum.map_join("\n", fn {module, function, arity, location} ->
      file = Keyword.get(location, :file, "<unknown>")
      line = Keyword.get(location, :line, "<unknown>")
      "    #{inspect(module)}.#{function}/#{arity} (#{file}:#{line})"
    end)
  end
end
```

### 2. Debug Mode Command

A new command has been added to toggle debug mode, allowing users to control whether detailed error information is displayed:

```elixir
defmodule Arca.Cli.Commands.CliDebugCommand do
  @moduledoc """
  Command for showing or toggling debug mode in the CLI.

  Debug mode controls whether detailed error information is displayed, including stack traces
  and other debugging context. This command allows users to check the current debug mode
  status and toggle it on or off.
  """

  use Arca.Cli.Command.BaseCommand

  config :"cli.debug",
    name: "cli.debug",
    about: "Show or toggle debug mode for detailed error information",
    args: [
      toggle: [
        value_name: "on|off",
        help: "Turn debug mode on or off",
        required: false
      ]
    ]

  @impl true
  def handle(args, _settings, _optimus) do
    toggle = args.args.toggle

    current = Application.get_env(:arca_cli, :debug_mode, false)

    case toggle do
      nil ->
        "Debug mode is currently #{if current, do: "ON", else: "OFF"}"

      "on" ->
        Application.put_env(:arca_cli, :debug_mode, true)
        save_debug_setting(true)
        "Debug mode is now ON"

      "off" ->
        Application.put_env(:arca_cli, :debug_mode, false)
        save_debug_setting(false)
        "Debug mode is now OFF"

      _ ->
        {:error, :invalid_argument, "Invalid value '#{toggle}'. Use 'on' or 'off'."}
    end
  end

  # Helper function to save the debug setting to configuration
  defp save_debug_setting(value) do
    if Code.ensure_loaded?(Arca.Config) && function_exported?(Arca.Config, :put, 2) do
      Arca.Config.put("cli.debug_mode", value)
    end
  end
end
```

### 3. Updated Command Execution in Arca.Cli

The `execute_command/5` function has been updated to use the ErrorHandler module for consistent error handling:

```elixir
def execute_command(cmd, args, settings, optimus, handler) do
  try do
    # Normal command execution with enhanced error handling
    result = handler.handle(args, settings, optimus)

    # Normalize error formats using the central ErrorHandler
    case result do
      {:error, reason} when is_binary(reason) ->
        # Convert legacy error format to enhanced format with debug info
        ErrorHandler.create_error(
          :command_failed,
          reason,
          error_location: "#{handler}.handle/3"
        )

      {:error, error_type, reason} ->
        # Convert standard error format to enhanced format with debug info
        ErrorHandler.create_error(
          error_type,
          reason,
          error_location: "#{handler}.handle/3"
        )

      {:error, error_type, reason, _debug_info} = enhanced_error ->
        # Already using enhanced format, pass through
        enhanced_error

      other ->
        # Non-error results are returned as success
        {:ok, other}
    end
  rescue
    e ->
      stacktrace = __STACKTRACE__

      # Log the detailed error with stack trace for server logs
      Logger.error("Error executing command #{cmd}: #{inspect(e)}\n#{Exception.format_stacktrace(stacktrace)}")

      # Create an enhanced error with both error message and debug info
      ErrorHandler.create_error(
        :command_failed,
        "Error executing command #{cmd}: #{Exception.message(e)}",
        stack_trace: stacktrace,
        original_error: e,
        error_location: "#{__MODULE__}.execute_command/5"
      )
  end
end
```

### 4. Updated REPL Error Handling

The REPL module has been updated to handle enhanced error tuples and use the centralized error formatter:

```elixir
# Updated REPL error handling to use the ErrorHandler module
def print_error(error_message) do
  # Check if debug mode is enabled
  debug_enabled = Application.get_env(:arca_cli, :debug_mode, false)

  # Format the error using the central ErrorHandler
  formatted = ErrorHandler.format_error(error_message, debug: debug_enabled)

  # Print the formatted error
  IO.puts(formatted)
  :ok
end

# Updated REPL loop to handle enhanced error tuples
defp repl(args, settings, optimus) do
  with {:ok, input} <- read(args, settings, optimus),
       {:ok, result} <- eval(input, settings, optimus),
       {:ok, _} <- print_result(result) do
    # Handle different result types
    case result do
      {:ok, :quit} ->
        {:ok, :quit}

      # Continue the REPL loop
      _ ->
        repl(args, settings, optimus)
    end
  else
    # Input was EOF (user pressed Ctrl+D), treat as quit
    {:eof} ->
      {:ok, :quit}

    # Handle enhanced error format (with debug info)
    {:error, error_type, reason, debug_info} ->
      # Use ErrorHandler to format and display the error
      debug_enabled = Application.get_env(:arca_cli, :debug_mode, false)
      formatted = ErrorHandler.format_error({:error, error_type, reason, debug_info}, debug: debug_enabled)
      IO.puts(formatted)

      # Continue the REPL
      repl(args, settings, optimus)

    # Handle standard error tuples for backward compatibility
    {:error, error_type, reason} ->
      # Convert to enhanced error format
      enhanced_error = ErrorHandler.create_error(error_type, reason, error_location: "Arca.Cli.Repl")

      # Format and display
      debug_enabled = Application.get_env(:arca_cli, :debug_mode, false)
      formatted = ErrorHandler.format_error(enhanced_error, debug: debug_enabled)
      IO.puts(formatted)

      # Continue the REPL
      repl(args, settings, optimus)
  end
end
```

### 5. Test Case

A test suite was created to verify the improved error handling:

```elixir
defmodule Arca.Cli.ErrorHandlingTest do
  use ExUnit.Case
  import ExUnit.CaptureIO

  # Setup function to prepare the test environment
  setup do
    # Save the original debug mode setting
    original_debug_mode = Application.get_env(:arca_cli, :debug_mode, false)

    # Restore the original setting after the test
    on_exit(fn ->
      Application.put_env(:arca_cli, :debug_mode, original_debug_mode)
    end)

    :ok
  end

  test "with debug mode disabled handles raised exceptions with basic info" do
    # Ensure debug mode is off
    Application.put_env(:arca_cli, :debug_mode, false)

    output = capture_io(fn ->
      # Run a command that will raise an exception
      Arca.Cli.main(["cli.error"])
    end)

    # Basic error info should be shown
    assert output =~ "Error (command_failed): Error executing command cli.error: This is a test exception"

    # Debug info should not be shown
    refute output =~ "Debug Information:"
    refute output =~ "Stack trace:"
  end

  test "with debug mode enabled handles raised exceptions with detailed debug info" do
    # Enable debug mode
    Application.put_env(:arca_cli, :debug_mode, true)

    output = capture_io(fn ->
      # Run a command that will raise an exception
      Arca.Cli.main(["cli.error"])
    end)

    # Both basic and detailed error info should be shown
    assert output =~ "Error (command_failed): Error executing command cli.error: This is a test exception"
    assert output =~ "Debug Information:"
    assert output =~ "Stack trace:"
    assert output =~ "Time:"
    assert output =~ "Location:"
    assert output =~ "Original error:"
  end

  test "with debug mode disabled handles legacy error tuples" do
    # Ensure debug mode is off
    Application.put_env(:arca_cli, :debug_mode, false)

    # Create a legacy error tuple
    error = {:error, "Legacy error message"}

    # Format the error
    formatted = Arca.Cli.ErrorHandler.format_error(error)

    # Should convert to enhanced format but not show debug info
    assert formatted =~ "Error (unknown_error): Legacy error message"
    refute formatted =~ "Debug Information:"
  end

  test "with debug mode enabled handles standard error tuples with debug info" do
    # Enable debug mode
    Application.put_env(:arca_cli, :debug_mode, true)

    # Create an enhanced error tuple
    error = Arca.Cli.ErrorHandler.create_error(
      :invalid_argument,
      "Invalid value provided",
      error_location: "TestModule.test_function/2"
    )

    # Format the error with debug mode enabled
    formatted = Arca.Cli.ErrorHandler.format_error(error, debug: true)

    # Should show both basic and detailed error info
    assert formatted =~ "Error (invalid_argument): Invalid value provided"
    assert formatted =~ "Debug Information:"
    assert formatted =~ "Location: TestModule.test_function/2"
    assert formatted =~ "Time:"
  end

  test "errors are not displayed twice" do
    # Enable debug mode
    Application.put_env(:arca_cli, :debug_mode, false)

    output = capture_io(fn ->
      # Run a command that will raise an exception
      Arca.Cli.main(["cli.error"])
    end)

    # Error message should appear exactly once
    assert String.split(output, "Error (command_failed)") |> length() == 2
  end
end
```

## Outstanding Work

The current implementation provides a strong foundation for error handling in Arca CLI, but several enhancements could be made in the future:

### 1. Command-Specific Error Handling

A protocol-based approach could be implemented to allow commands to define their own error handling behavior. This would enable commands to provide more context-specific error messages and recovery strategies.

```elixir
# Proposed protocol for command-specific error handling
defprotocol Arca.Cli.CommandErrorHandler do
  @doc "Handle command-specific errors"
  def handle_error(command, error_tuple, opts)
end

# Example implementation for a specific command
defimpl Arca.Cli.CommandErrorHandler, for: YourApp.Commands.CustomCommand do
  def handle_error(_command, {:error, :invalid_input, reason, debug_info}, opts) do
    # Custom handling for invalid input errors
    custom_message = "The input was invalid: #{reason}. Please check the documentation."

    # Return a modified error tuple
    {:error, :invalid_input, custom_message, debug_info}
  end

  # Pass through other errors
  def handle_error(_command, error_tuple, _opts), do: error_tuple
end
```

### 2. Improved Debug Information Display

The current implementation displays debug information in a basic text format. Future improvements could include:

- Color-coded error information (using ANSI colors for terminal output)
- Better structured stack traces with improved readability
- Collapsible sections for verbose information
- Terminal hyperlinks for file paths to enable easy navigation

```elixir
# Example of enhanced debug information formatting
defp format_debug_info(debug_info) do
  [
    IO.ANSI.bright() <> IO.ANSI.yellow() <> "Debug Information:" <> IO.ANSI.reset(),
    "  " <> IO.ANSI.cyan() <> "Time:" <> IO.ANSI.reset() <> " #{DateTime.to_string(debug_info.timestamp)}",
    format_location(debug_info.error_location),
    format_original_error(debug_info.original_error),
    "  " <> IO.ANSI.cyan() <> "Stack trace:" <> IO.ANSI.reset(),
    format_stack_trace(debug_info.stack_trace)
  ]
  |> Enum.reject(&is_nil/1)
  |> Enum.join("\n")
end
```

## Benefits

The improved error handling system in Arca CLI provides several key benefits:

1. **Enhanced Debugging**: Detailed error information is available on demand through debug mode.
2. **Consistent Error Format**: All errors follow a standard format for better readability.
3. **No Duplicate Messages**: The centralized error handler ensures errors are reported only once.
4. **Better Context**: Error messages include the error type, providing better context about what went wrong.
5. **Backward Compatibility**: The system handles both legacy and modern error formats.
6. **Improved Developer Experience**: Debugging errors is faster and more efficient with enhanced error information.
7. **User Control**: Users can toggle debug mode on or off based on their needs.

## Related Documentation

For more information, see:

- [User Guide](/stp/usr/user_guide.md)
- [Reference Guide](/stp/usr/reference_guide.md)
- [Deployment Guide](/stp/usr/deployment_guide.md)
- [Detailed Design](/stp/eng/tpd/4_detailed_design.md)

## Benefits

1. **Improved User Experience**: Users get more informative and non-duplicate error messages.
2. **Enhanced Debugging**: Debug mode provides detailed error information on demand.
3. **Consistent Error Handling**: Standardized error formatting and display across the application.
4. **Better Error Context**: Stack traces and error locations help with troubleshooting.
5. **Backward Compatibility**: Support for both legacy and new error formats.

## Documentation

- Updated [User Guide](/stp/usr/user_guide.md) with information about the debug mode and improved error messages
- Updated [Reference Guide](/stp/usr/reference_guide.md) with details about the new error handling framework
- Updated [Deployment Guide](/stp/usr/deployment_guide.md) with information about the new debug capability
