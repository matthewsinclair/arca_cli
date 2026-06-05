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

  defmacro __using__(_) do
    quote do
      import Arca.Cli.ErrorHandler,
        only: [
          create_error_with_location: 2,
          create_error_with_location: 3,
          create_and_format_error_with_location: 2,
          create_and_format_error_with_location: 3,
          err_cloc: 2,
          err_cloc: 3,
          err_cfloc: 2,
          err_cfloc: 3
        ]
    end
  end

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

  @doc """
  Normalize error format to the enhanced format.

  This function ensures all error types are converted to the enhanced format
  with debug information.

  ## Parameters
    - error: The error to normalize (any format)
    - opts: Options for additional debug information if needed

  ## Returns
    - Enhanced error tuple

  ## Examples

      iex> ErrorHandler.normalize_error({:error, "Something failed"})
      {:error, :unknown_error, "Something failed", %{...}}

      iex> ErrorHandler.normalize_error({:error, :command_failed, "Unknown command"})
      {:error, :command_failed, "Unknown command", %{...}}
  """
  @spec normalize_error(
          {:error, error_type(), String.t()} | {:error, String.t()} | any(),
          Keyword.t()
        ) :: enhanced_error() | any()

  # Define function head with default parameters
  def normalize_error(error, opts \\ [])

  def normalize_error({:error, error_type, reason}, opts) do
    create_error(error_type, reason, opts)
  end

  def normalize_error({:error, reason}, opts) when is_binary(reason) do
    create_error(:unknown_error, reason, opts)
  end

  # Already in enhanced format or non-error value, pass through
  def normalize_error({:error, _type, _reason, _debug} = enhanced_error, _opts),
    do: enhanced_error

  def normalize_error(value, _opts), do: value

  @doc """
  Convert an enhanced error to a standard error (for backward compatibility).

  ## Parameters
    - error: The enhanced error tuple

  ## Returns
    - Standard error tuple of the form {:error, error_type, reason}

  ## Examples

      iex> ErrorHandler.to_standard_error({:error, :command_failed, "Failed", debug_info})
      {:error, :command_failed, "Failed"}
  """
  @spec to_standard_error(enhanced_error()) :: {:error, error_type(), String.t()}
  def to_standard_error({:error, error_type, reason, _debug_info}) do
    {:error, error_type, reason}
  end

  # Already standard or pass through
  def to_standard_error({:error, _type, _reason} = standard_error), do: standard_error
  def to_standard_error(value), do: value

  @doc """
  Convert an enhanced or standard error to a legacy error (for backward compatibility).

  ## Parameters
    - error: The error tuple to convert

  ## Returns
    - Legacy error tuple of the form {:error, reason}

  ## Examples

      iex> ErrorHandler.to_legacy_error({:error, :command_failed, "Failed", debug_info})
      {:error, "Failed"}
  """
  @spec to_legacy_error(enhanced_error() | {:error, error_type(), String.t()}) ::
          {:error, String.t()}
  def to_legacy_error({:error, _error_type, reason, _debug_info}) do
    {:error, reason}
  end

  def to_legacy_error({:error, _error_type, reason}) do
    {:error, reason}
  end

  # Already legacy or pass through
  def to_legacy_error({:error, reason} = legacy_error) when is_binary(reason), do: legacy_error
  def to_legacy_error(value), do: value

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

  @doc """
  Creates an enhanced error tuple with automatic location tracking.

  This macro automatically adds the current module and function name 
  to the error location, simplifying error creation.

  ## Parameters
    - error_type: The type of error (atom)
    - message: Description of the error
    - opts: Additional options for create_error (optional)

  ## Returns
    - An enhanced error tuple with automatically populated location

  ## Examples

      iex> create_error_with_location(:validation_error, "Invalid input")
      {:error, :validation_error, "Invalid input", %{error_location: "CurrentModule.current_function/1", ...}}
  """
  defmacro create_error_with_location(error_type, message, opts \\ []) do
    quote do
      error_location = "#{__MODULE__}.#{elem(__ENV__.function, 0)}/#{elem(__ENV__.function, 1)}"

      unquote(opts)
      |> Keyword.put(:error_location, error_location)
      |> (&Arca.Cli.ErrorHandler.create_error(unquote(error_type), unquote(message), &1)).()
    end
  end

  @doc """
  Creates and formats an error with automatic location tracking.

  This macro automatically adds the current module and function name 
  to the error location, simplifying error creation and formatting
  in a single operation.

  ## Parameters
    - error_type: The type of error (atom)
    - message: Description of the error
    - opts: Additional options for create_error (optional)

  ## Returns
    - A formatted error string ready for display

  ## Examples

      iex> create_and_format_error_with_location(:validation_error, "Invalid input")
      "Error (validation_error): Invalid input"
  """
  defmacro create_and_format_error_with_location(error_type, message, opts \\ []) do
    quote do
      error_location = "#{__MODULE__}.#{elem(__ENV__.function, 0)}/#{elem(__ENV__.function, 1)}"

      unquote(opts)
      |> Keyword.put(:error_location, error_location)
      |> (&Arca.Cli.ErrorHandler.create_error(unquote(error_type), unquote(message), &1)).()
      |> Arca.Cli.ErrorHandler.format_error()
    end
  end

  @doc """
  Shorthand alias for create_error_with_location/3.

  This macro provides a shorter name for the create_error_with_location macro,
  with an 'err_' prefix to clearly identify it as an error-related function.

  ## Parameters
    - error_type: The type of error (atom)
    - message: Description of the error
    - opts: Additional options for create_error (optional)
    
  ## Returns
    - An enhanced error tuple with automatically populated location
  """
  defmacro err_cloc(error_type, message, opts \\ []) do
    quote do
      Arca.Cli.ErrorHandler.create_error_with_location(
        unquote(error_type),
        unquote(message),
        unquote(opts)
      )
    end
  end

  @doc """
  Shorthand alias for create_and_format_error_with_location/3.

  This macro provides a shorter name for the create_and_format_error_with_location macro,
  with an 'err_' prefix to clearly identify it as an error-related function.

  ## Parameters
    - error_type: The type of error (atom)
    - message: Description of the error
    - opts: Additional options for create_error (optional)
    
  ## Returns
    - A formatted error string ready for display
  """
  defmacro err_cfloc(error_type, message, opts \\ []) do
    quote do
      Arca.Cli.ErrorHandler.create_and_format_error_with_location(
        unquote(error_type),
        unquote(message),
        unquote(opts)
      )
    end
  end
end
