defmodule Arca.Cli.ErrorHandler do
  @moduledoc """
  Central module for handling and formatting errors in Arca CLI.

  This module provides standardized functions for creating, transforming, and
  formatting error tuples. It handles both legacy error formats for backward
  compatibility and enhanced formats that include debug information.

  Features:
  - Enhanced error tuples with debug context
  - Consistent error formatting
  - Debug mode support
  - Stack trace formatting
  - Legacy error format support
  - Macros for simplified error creation and formatting
  """

  @typedoc """
  Types of errors that can occur in CLI operations.
  Combines error types from Arca.Cli and BaseCommand.
  """
  # From Arca.Cli
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

  @typedoc """
  Standard result tuple for operations that might fail.
  """
  @type result(t) :: {:ok, t} | enhanced_error()

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

  ## Examples

      iex> ErrorHandler.create_error(:command_failed, "Unknown command")
      {:error, :command_failed, "Unknown command", %{...}}

      iex> ErrorHandler.create_error(:invalid_argument, "Invalid value", 
      ...>   error_location: "MyModule.my_function/2", 
      ...>   original_error: %ArgumentError{...})
      {:error, :invalid_argument, "Invalid value", %{...}}
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

  ## Examples

      iex> ErrorHandler.format_error({:error, :command_failed, "Unknown command"})
      "Error (command_failed): Unknown command"

      iex> ErrorHandler.format_error({:error, :command_failed, "Unknown command", debug_info}, debug: true)
      "Error (command_failed): Unknown command\\nDebug Information:..."
  """
  @spec format_error(
          enhanced_error() | {:error, error_type(), String.t()} | {:error, String.t()} | any(),
          Keyword.t()
        ) :: String.t()

  # Define function head with default parameters
  def format_error(error, opts \\ [])

  def format_error({:error, error_type, reason, debug_info}, opts) do
    base_error = error_line(context(error_type, opts), format_reason(reason))

    # Add debug information if enabled and available
    if Keyword.get(opts, :debug, false) && debug_info do
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

  @doc """
  The context a message is reported against.

  The caller's `:command` when it knows one, otherwise a human phrase for the
  error type. `nil` when neither is available, which renders as a bare
  `error: <message>` rather than inventing a context.
  """
  @spec context(error_type(), Keyword.t()) :: String.t() | nil
  def context(error_type, opts \\ []) do
    case Keyword.get(opts, :command) do
      nil -> context_for_type(error_type)
      command -> to_string(command)
    end
  end

  @doc """
  A human-readable phrase for an error type.

  The one place error types become words. `nil` for types that say nothing a
  user would find useful, so those render without a context segment.
  """
  @spec context_for_type(error_type() | atom()) :: String.t() | nil
  def context_for_type(:command_not_found), do: "command not found"
  def context_for_type(:command_failed), do: "command failed"
  def context_for_type(:invalid_argument), do: "invalid argument"
  def context_for_type(:config_error), do: "configuration error"
  def context_for_type(:file_not_found), do: "file not found"
  def context_for_type(:file_not_readable), do: "file not readable"
  def context_for_type(:file_not_writable), do: "file not writable"
  def context_for_type(:decode_error), do: "decode error"
  def context_for_type(:encode_error), do: "encode error"
  def context_for_type(:unknown_error), do: nil
  def context_for_type(nil), do: nil

  def context_for_type(error_type) when is_atom(error_type) do
    error_type |> Atom.to_string() |> String.replace("_", " ")
  end

  @doc """
  Render one error line in the project's dialect: `error: <context>: <message>`.

  Every user-visible error goes through here, so the shape is stated once.
  """
  @spec error_line(String.t() | nil, String.t()) :: String.t()
  def error_line(nil, message), do: String.trim("error: #{message}")
  def error_line("", message), do: error_line(nil, message)
  def error_line(context, message), do: String.trim("error: #{context}: #{message}")

  @doc """
  Render an error reason as text.

  A binary reason is already text and is passed through. Inspecting it would
  wrap it in quotes and show a user `"Key not found"` rather than
  `Key not found`.
  """
  @spec format_reason(term()) :: String.t()
  def format_reason(reason) when is_binary(reason), do: reason
  def format_reason(reason) when is_atom(reason), do: to_string(reason)

  def format_reason(reason) when is_list(reason) do
    Enum.map_join(reason, " ", &format_reason/1)
  end

  def format_reason(reason), do: inspect(reason)

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

  # Format the error location if available
  @spec format_location(String.t() | nil) :: String.t() | nil
  defp format_location(nil), do: nil
  defp format_location(location), do: "  Location: #{location}"

  # Format the original error if available
  @spec format_original_error(any() | nil) :: String.t() | nil
  defp format_original_error(nil), do: nil
  defp format_original_error(error), do: "  Original error: #{inspect(error)}"

  # Format stack trace in a readable way
  @spec format_stack_trace(list() | nil) :: String.t()
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
