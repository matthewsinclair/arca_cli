defmodule Arca.Cli.Command.BaseCommand do
  @moduledoc """
  Use an `Arca.Cli.Command.BaseCommand` to quickly and easily build a new CLI command.

  ## Command Naming Convention

  When creating a command, it's important to follow the naming convention:

  1. The module name must end with "Command" (e.g., `AboutCommand`, `StatusCommand`)
  2. The command name specified in the `config/2` macro must match the downcased module name 
     without the "Command" suffix (e.g., `:about` for `AboutCommand`, `:status` for `StatusCommand`)

  This is enforced at compile time to prevent silent failures at runtime.

  ## Example

  ```elixir
  defmodule MyApp.Cli.Commands.HelloCommand do
    use Arca.Cli.Command.BaseCommand
    
    # Correct: module is HelloCommand, command name is :hello
    config :hello,
      name: "hello",
      about: "Say hello to the user"
      
    @impl true
    def handle(_args, _settings, _optimus) do
      "Hello, world!"
    end
  end
  ```
  """

  @typedoc """
  Represents possible error types from command operations
  """
  @type error_type ::
          :validation_error
          | :command_mismatch
          | :not_implemented
          | :invalid_module_name
          | :invalid_command_name
          | :help_requested

  @typedoc """
  Result type for command validation operations
  """
  @type validation_result :: {:ok, atom()} | {:error, error_type(), String.t()}

  @typedoc """
  Generic result type for operations that can fail
  """
  @type result(t) :: {:ok, t} | {:error, error_type(), String.t()}

  @doc """
  Create a standardized error tuple with type and reason
  """
  @spec create_error(error_type(), String.t()) :: {:error, error_type(), String.t()}
  def create_error(error_type, reason) do
    {:error, error_type, reason}
  end

  @doc """
  Convert a 3-tuple error to a 2-tuple error for backward compatibility.
  Also passes through non-error values unchanged.
  """
  @spec to_legacy_error({:error, error_type(), String.t()}) :: {:error, String.t()}
  def to_legacy_error({:error, _error_type, reason}) do
    {:error, reason}
  end

  @spec to_legacy_error(any()) :: any()
  def to_legacy_error(value), do: value

  @doc """
  Implement base functionality for a Command.
  """
  defmacro __using__(_opts) do
    quote do
      import unquote(__MODULE__), only: [config: 2]

      alias Arca.Cli.Command.BaseCommand
      import Arca.Cli.Utils
      require Logger
      @behaviour Arca.Cli.Command.CommandBehaviour

      Module.register_attribute(__MODULE__, :cmdcfg, accumulate: false)

      @doc """
      Default command handler.

      Handles the `:help` atom and `{:help, subcmd}` tuple in a type-safe way; any
      other invocation on a command that does not override `handle/3` returns a
      `:not_implemented` error.

      Marked `defoverridable` so each command's own `handle/3` replaces this
      default cleanly, without generating shadowed-clause warnings.
      """
      @impl Arca.Cli.Command.CommandBehaviour
      def handle(:help, _settings, _optimus), do: :help

      def handle({:help, subcmd}, _settings, _optimus), do: {:help, subcmd}

      def handle(_args, _settings, _optimus) do
        this_function_is_not_implemented()
        Arca.Cli.Command.BaseCommand.create_error(:not_implemented, "Command not implemented")
      end

      defoverridable handle: 3

      @before_compile unquote(__MODULE__)
    end
  end

  @doc """
  Configure a command with the given name and options.

  ## Parameters

  - `cmd`: The command name (as an atom) that will be used for CLI dispatch.
    MUST match the downcased module name without the "Command" suffix.
  - `opts`: Keyword list of options for the command configuration.

  ## Examples

  ```elixir
  # In a module named MyApp.Cli.Commands.HelloCommand:
  config :hello,
    name: "hello",
    about: "Say hello to the user"
  ```

  ## Validation

  This macro performs compile-time validation to ensure the command name
  matches the module name convention. This prevents silent runtime dispatch failures.

  ### Validation Rules

  1. The module name must end with "Command" suffix
     - Valid: `HelloCommand`, `GetDataCommand`
     - Invalid: `Hello`, `GetData`

  2. The command name (first argument to `config`) must equal the module suffix
     with "Command" removed and the remainder **downcased**. Downcasing does not
     insert underscores, so a multi-word module name produces a single run of
     letters:
     - Valid: `HelloCommand` with `:hello`, `GetDataCommand` with `:getdata`
     - Invalid: `HelloCommand` with `:greeting`, `GetDataCommand` with `:get_data`

     Use dot notation for a command whose name has more than one part --
     `SysInfoCommand` with `:"sys.info"` -- which is what every command in this
     project does. The dot form is transformed before validation, so the parts
     do not have to survive downcasing intact.

  ### What's Fixed

  This validation resolves a subtle bug where mismatched command names would be registered
  but fail silently at runtime during dispatch. The dispatch process in `Arca.Cli.handler_for_command/2`
  expects command names to follow this convention, and will now be validated at compile time.
  """
  defmacro config(cmd, opts) do
    quote do
      # Use validate_module_name and validate_command_name in place of in-macro code
      with {:ok, expected_cmd} <- Arca.Cli.Command.BaseCommand.validate_module_name(__MODULE__),
           {:ok, transformed_cmd} <-
             Arca.Cli.Command.BaseCommand.transform_dot_command(unquote(cmd)),
           {:ok, _} <-
             Arca.Cli.Command.BaseCommand.validate_command_name(expected_cmd, transformed_cmd) do
        @cmdcfg [{unquote(cmd), unquote(opts)}]
      else
        {:error, :invalid_module_name, reason} ->
          # Raise compile-time error for invalid module name
          raise ArgumentError, reason

        {:error, :invalid_command_name, reason} ->
          # Raise compile-time error for command name mismatch
          raise ArgumentError, reason

        {:error, error_type, reason} ->
          # Catch-all for other error types
          raise ArgumentError, "#{error_type}: #{reason}"
      end
    end
  end

  @doc """
  Validates that the module name follows the command naming convention.
  Returns the expected command name derived from the module name.
  """
  @spec validate_module_name(module()) :: validation_result()
  def validate_module_name(module_name) do
    module_name_parts = Module.split(module_name)
    module_suffix = List.last(module_name_parts)

    if String.ends_with?(module_suffix, "Command") do
      suffix_without_command = String.replace_suffix(module_suffix, "Command", "")
      expected_cmd = String.to_atom(String.downcase(suffix_without_command))
      {:ok, expected_cmd}
    else
      create_error(:invalid_module_name, "Command module name must end with 'Command'")
    end
  end

  @doc """
  Transforms dot notation commands (e.g., 'sys.info') to match expected format for validation.
  """
  @spec transform_dot_command(atom()) :: validation_result()
  def transform_dot_command(cmd) when is_atom(cmd) do
    cmd_str = Atom.to_string(cmd)

    if String.contains?(cmd_str, ".") do
      transformed_cmd =
        cmd_str
        |> String.split(".")
        |> Enum.map(&String.capitalize/1)
        |> Enum.join("")
        |> String.downcase()
        |> String.to_atom()

      {:ok, transformed_cmd}
    else
      {:ok, cmd}
    end
  end

  @doc """
  Validates that the command name matches the expected command name.
  """
  @spec validate_command_name(atom(), atom()) :: validation_result()
  def validate_command_name(expected_cmd, cmd) do
    cond do
      expected_cmd == cmd ->
        # Standard command name matches directly
        {:ok, cmd}

      true ->
        # Command name doesn't match in any format
        create_error(
          :command_mismatch,
          "Command name mismatch: config defines command as #{inspect(cmd)} " <>
            "but module name expects #{inspect(expected_cmd)}. " <>
            "The command name must match the module name (without 'Command' suffix, downcased)."
        )
    end
  end

  defmacro __before_compile__(env) do
    cmdcfg = Module.get_attribute(env.module, :cmdcfg)
    escaped_cmdcfg = Macro.escape(cmdcfg)

    quote do
      @cmdcfg unquote(escaped_cmdcfg)

      @doc """
      Provide the Optimus config for the command.
      """
      @impl Arca.Cli.Command.CommandBehaviour
      def config() do
        @cmdcfg
      end

      # Legacy compatibility handler to support both old and new error formats.
      # Ensures code depending on the old error format continues to work.

      @doc """
      Convert result to legacy format for backward compatibility.
      This allows new code to use the improved error format while maintaining
      compatibility with code that expects the old format.
      """
      @spec handle_legacy_result(any()) :: any()
      def handle_legacy_result(result) do
        Arca.Cli.Command.BaseCommand.to_legacy_error(result)
      end
    end
  end
end
