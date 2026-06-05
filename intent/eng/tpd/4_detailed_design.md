---
verblock: "25 Mar 2025:v0.3: Fixed command sorting implementation"
---

# 4. Detailed Design

## 4.1 Command System

### 4.1.1 Command Behaviour

The `Arca.Cli.Command.CommandBehaviour` defines the interface that all commands must implement:

```elixir
defmodule Arca.Cli.Command.CommandBehaviour do
  @callback config() :: Keyword.t()
  @callback handle(map(), map(), struct()) :: any()
end
```

- `config/0`: Returns the command configuration, including name, arguments, options, and flags
- `handle/3`: Implements the command logic, receiving parsed arguments, settings, and the Optimus parser

### 4.1.2 BaseCommand Implementation

The `Arca.Cli.Command.BaseCommand` provides a base implementation for commands using a macro-based DSL:

```elixir
defmodule Arca.Cli.Command.BaseCommand do
  defmacro __using__(_opts) do
    quote do
      @behaviour Arca.Cli.Command.CommandBehaviour
      import Arca.Cli.Command.BaseCommand, only: [config: 2]

      # Default implementations
      def config, do: []
      def handle(_args, _settings, _optimus), do: :ok

      defoverridable [config: 0, handle: 3]
    end
  end

  defmacro config(name, opts) do
    # Implementation of the config DSL
  end
end
```

### 4.1.3 Command Registration

Commands are registered through Configurators, which provide a list of command modules to the system:

```elixir
defmodule YourApp.Cli.Configurator do
  use Arca.Cli.Configurator.BaseConfigurator

  config :your_app_cli,
    commands: [
      YourApp.Cli.Commands.CustomCommand,
      YourApp.Cli.Commands.AnotherCommand,
    ],
    # Other configuration...
end
```

### 4.1.4 Command Dispatch

The command dispatch process involves:

1. Parsing the command line input
2. Identifying the target command from registered commands
3. Validating inputs against the command's argument specification
4. Invoking the command's `handle/3` function with the parsed arguments
5. Handling any errors that occur during execution
6. Formatting and returning the result

## 4.1.5 Error Handling System

The error handling system is designed to provide consistent, informative error messages across both CLI and REPL modes, with support for detailed debugging information when needed.

### Error Handler Module

The `Arca.Cli.ErrorHandler` module centralizes error handling logic:

```elixir
defmodule Arca.Cli.ErrorHandler do
  @moduledoc """
  Central module for handling and formatting errors in Arca CLI.
  """

  require Logger

  @typedoc "Types of errors that can occur in CLI operations"
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
          # From Command.BaseCommand
          | :validation_error
          | :command_mismatch
          | :not_implemented
          | :invalid_module_name
          | :invalid_command_name
          | :help_requested

  @typedoc "Debug information attached to errors"
  @type debug_info :: %{
          stack_trace: list() | nil,
          error_location: String.t() | nil,
          original_error: any() | nil,
          timestamp: DateTime.t()
        }

  @typedoc "Enhanced error tuple with debug information"
  @type enhanced_error :: {:error, error_type(), String.t(), debug_info() | nil}

  @doc "Create an enhanced error with debug information"
  @spec create_error(error_type(), String.t(), Keyword.t()) :: enhanced_error()

  @doc "Format errors for display with optional debug information"
  @spec format_error(
          enhanced_error() | {:error, error_type(), String.t()} | {:error, String.t()} | any(),
          Keyword.t()
        ) :: String.t()

  @doc "Normalize error format to enhanced format"
  @spec normalize_error(
          {:error, error_type(), String.t()} | {:error, String.t()} | any(),
          Keyword.t()
        ) :: enhanced_error() | any()

  # Implementation details...
end
```

### Debug Mode Command

A dedicated command allows users to toggle debug mode on or off:

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
      nil -> "Debug mode is currently #{if current, do: "ON", else: "OFF"}"
      "on" ->
        Application.put_env(:arca_cli, :debug_mode, true)
        save_debug_setting(true)
        "Debug mode is now ON"
      "off" ->
        Application.put_env(:arca_cli, :debug_mode, false)
        save_debug_setting(false)
        "Debug mode is now OFF"
      _ -> {:error, :invalid_argument, "Invalid value '#{toggle}'. Use 'on' or 'off'."}
    end
  end

  # Helper for persisting the setting
  defp save_debug_setting(value) do
    if Code.ensure_loaded?(Arca.Config) && function_exported?(Arca.Config, :put, 2) do
      Arca.Config.put("cli.debug_mode", value)
    end
  end
end
```

### Error Flow

The error handling flow ensures consistent processing of errors:

1. **Command Execution**

   ```elixir
   def execute_command(cmd, args, settings, optimus, handler) do
     try do
       result = handler.handle(args, settings, optimus)
       # Normalize error formats to enhanced format
       case result do
         {:error, reason} when is_binary(reason) ->
           ErrorHandler.create_error(:command_failed, reason, error_location: "#{handler}.handle/3")
         {:error, error_type, reason} ->
           ErrorHandler.create_error(error_type, reason, error_location: "#{handler}.handle/3")
         {:error, error_type, reason, _debug_info} = enhanced_error ->
           enhanced_error
         other ->
           {:ok, other}
       end
     rescue
       e ->
         stacktrace = __STACKTRACE__
         Logger.error("Error executing command #{cmd}: #{inspect(e)}\n#{Exception.format_stacktrace(stacktrace)}")
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

2. **Error Display**

   ```elixir
   def handle_error(error_tuple) do
     debug_enabled = Application.get_env(:arca_cli, :debug_mode, false)
     formatted = ErrorHandler.format_error(error_tuple, debug: debug_enabled)
     IO.puts(formatted)
   end
   ```

### Error Types

The system defines standardized error types to provide context about failures:

| Error Type           | Description                                |
| -------------------- | ------------------------------------------ |
| `:command_not_found` | No registered command matches the input    |
| `:command_failed`    | Command execution failed                   |
| `:invalid_argument`  | Invalid argument provided to command       |
| `:config_error`      | Error in configuration system              |
| `:file_not_found`    | Referenced file doesn't exist              |
| `:decode_error`      | Failed to decode data (e.g., JSON parsing) |
| `:validation_error`  | Command input validation failed            |
| `:help_requested`    | User requested help for a command          |
| `:unknown_error`     | Unspecified error type                     |

### Debug Information

The enhanced error format includes debug information when enabled:

```elixir
{:error, :command_failed, "Error executing command", %{
  stack_trace: [...stack_trace_entries...],
  error_location: "Arca.Cli.Commands.ExampleCommand.handle/3",
  original_error: %RuntimeError{message: "Original error message"},
  timestamp: ~U[2025-04-17 15:30:45.123Z]
}}
```

This debug information is formatted for display when debug mode is enabled:

```
Error (command_failed): Error executing command
Debug Information:
  Time: 2025-04-17 15:30:45.123Z
  Location: Arca.Cli.Commands.ExampleCommand.handle/3
  Original error: %RuntimeError{message: "Original error message"}
  Stack trace:
    Elixir.Arca.Cli.execute_command/5 (lib/arca_cli.ex:672)
    Elixir.Arca.Cli.handle_subcommand/4 (lib/arca_cli.ex:614)
    Elixir.Arca.Cli.main/1 (lib/arca_cli.ex:233)
```

### Outstanding Enhancements

Future improvements to the error handling system could include:

1. **Command-specific error handlers** using protocols to allow custom error formatting
2. **Enhanced formatting** with ANSI colors for better visual hierarchy
3. **Clickable file paths** in stack traces for improved developer experience
4. **Error handling macros** to simplify error creation and formatting with automatic location tracking

### Error Handling Macros

To simplify error creation and formatting, a macro-based approach can be implemented:

```elixir
defmodule Arca.Cli.ErrorHandler do
  # Existing code...

  defmacro __using__(_) do
    quote do
      import Arca.Cli.ErrorHandler, only: [
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

  # Creates an error with automatic location tracking
  defmacro create_error_with_location(error_type, message, opts \\ []) do
    quote do
      error_location = "#{__MODULE__}.#{elem(__ENV__.function, 0)}/#{elem(__ENV__.function, 1)}"

      unquote(opts)
      |> Keyword.put(:error_location, error_location)
      |> (&Arca.Cli.ErrorHandler.create_error(unquote(error_type), unquote(message), &1)).()
    end
  end

  # Creates and formats an error with automatic location tracking
  defmacro create_and_format_error_with_location(error_type, message, opts \\ []) do
    quote do
      error_location = "#{__MODULE__}.#{elem(__ENV__.function, 0)}/#{elem(__ENV__.function, 1)}"

      unquote(opts)
      |> Keyword.put(:error_location, error_location)
      |> (&Arca.Cli.ErrorHandler.create_error(unquote(error_type), unquote(message), &1)).()
      |> Arca.Cli.ErrorHandler.format_error()
    end
  end

  # Shorthand alias for create_error_with_location
  defmacro err_cloc(error_type, message, opts \\ []) do
    quote do
      Arca.Cli.ErrorHandler.create_error_with_location(
        unquote(error_type),
        unquote(message),
        unquote(opts)
      )
    end
  end

  # Shorthand alias for create_and_format_error_with_location
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
```

This approach provides several benefits:

1. **Automatic location tracking**: The macro automatically captures the current module and function name
2. **Simplified usage**: Reduces boilerplate code when creating and formatting errors
3. **Consistency**: Ensures standardized error formatting across the codebase

Example usage:

```elixir
# Before: Manual error creation and formatting
defp validate_limit(ctx, limit) when not is_integer(limit) or limit <= 0 do
  module = __MODULE__
  function = "#{elem(__ENV__.function, 0)}/#{elem(__ENV__.function, 1)}"
  error_location = "#{module}.#{function}"

  error = ErrorHandler.create_error(
    :validation_error,
    "Limit must be a positive integer",
    error_location: error_location
  )

  ctx
  |> Ctx.add_error(:validation, ErrorHandler.format_error(error))
  |> Ctx.complete()
end

# After: Using the verbose macro
defp validate_limit(ctx, limit) when not is_integer(limit) or limit <= 0 do
  ctx
  |> Ctx.add_error(:validation, create_and_format_error_with_location(
       :validation_error,
       "Limit must be a positive integer"
     ))
  |> Ctx.complete()
end

# Simplified: Using shorthand aliases
defp validate_limit_short(ctx, limit) when not is_integer(limit) or limit <= 0 do
  # The err_cfloc macro provides a shorter name with the same functionality
  ctx
  |> Ctx.add_error(:validation, err_cfloc(:validation_error, "Limit must be a positive integer"))
  |> Ctx.complete()
end

# For cases where formatting is needed separately
defp validate_and_store_limit(ctx, limit) when not is_integer(limit) or limit <= 0 do
  # Create the error with automatic location tracking using shorthand
  error = err_cloc(:validation_error, "Limit must be a positive integer")

  # Store the error for later or format it conditionally
  ctx
  |> Ctx.store_error(error)
  |> Ctx.complete()
end
```

## 4.2 REPL System

### 4.2.1 REPL Implementation

The REPL (Read-Eval-Print Loop) is implemented in the `Arca.Cli.Repl.Repl` module:

```elixir
defmodule Arca.Cli.Repl.Repl do
  def start(commands, settings, opts) do
    # Implementation of the REPL loop
  end

  def process_input(input, commands, settings, opts) do
    # Process user input and execute commands
  end

  def complete(input, commands) do
    # Implementation of tab completion
  end
end
```

### 4.2.2 Tab Completion

Tab completion is implemented through:

1. A completion function that matches partial input against available commands
2. Special handling for dot notation to complete hierarchical commands
3. Integration with `rlwrap` for enhanced terminal capabilities

Command completion logic:

```elixir
def complete(input, commands) do
  command_names = commands |> Enum.map(&(&1.config().name))

  matches = command_names
            |> Enum.filter(&String.starts_with?(&1, input))
            |> Enum.sort()

  case matches do
    [] -> []
    [exact] when exact == input -> []
    matches -> matches
  end
end
```

### 4.2.3 REPL Script Integration

The REPL integrates with external tools through shell scripts:

```bash
#!/bin/sh
# Check if rlwrap is available
if command -v rlwrap >/dev/null 2>&1; then
  # Generate completions file
  $SCRIPT_DIR/update_completions

  # Launch REPL with rlwrap for enhanced features
  rlwrap -f $SCRIPT_DIR/completions/completions.txt \
         -H $HOME/.arca/history \
         -C arca_cli \
         $SCRIPT_DIR/cli repl
else
  # Fall back to basic REPL
  $SCRIPT_DIR/cli repl
fi
```

## 4.3 History System

### 4.3.1 History GenServer

The History system is implemented as a GenServer for state management:

```elixir
defmodule Arca.Cli.History.History do
  use GenServer

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    # Load history from storage
    {:ok, %{history: [], opts: opts}}
  end

  def add(command) do
    GenServer.call(__MODULE__, {:add, command})
  end

  def get() do
    GenServer.call(__MODULE__, :get)
  end

  # GenServer callbacks for command handlers
end
```

### 4.3.2 History Persistence

History is persisted to a file for durability:

```elixir
defp load_history(opts) do
  path = history_path(opts)

  if File.exists?(path) do
    path
    |> File.read!()
    |> :erlang.binary_to_term()
  else
    []
  end
end

defp save_history(history, opts) do
  path = history_path(opts)
  dir = Path.dirname(path)

  :ok = File.mkdir_p(dir)
  :ok = File.write!(path, :erlang.term_to_binary(history))
end
```

### 4.3.3 History Commands

Several commands interact with the history system:

- `HistoryCommand`: Displays the command history
- `RedoCommand`: Re-executes a command from history by index
- `CliHistoryCommand`: Namespace-specific version of the history command

## 4.4 Configuration System

### 4.4.1 Configurator Behaviour

The `Arca.Cli.Configurator.ConfiguratorBehaviour` defines the interface for configurators:

```elixir
defmodule Arca.Cli.Configurator.ConfiguratorBehaviour do
  @callback commands() :: list()
  @callback setup() :: Optimus.t()
  @callback name() :: String.t() | nil
  @callback author() :: String.t() | nil
  @callback about() :: String.t()
  @callback description() :: String.t() | nil
  @callback version() :: String.t() | nil
  @callback allow_unknown_args() :: boolean()
  @callback parse_double_dash() :: boolean()
  @callback sorted() :: boolean()
  @callback create_base_config() :: list()
end
```

The `sorted()` callback controls whether commands should be displayed in alphabetical order (when `true`) or preserved in their defined order (when `false`).

### 4.4.2 BaseConfigurator Implementation

The `Arca.Cli.Configurator.BaseConfigurator` provides a base implementation using a macro-based DSL:

```elixir
defmodule Arca.Cli.Configurator.BaseConfigurator do
  defmacro __using__(_opts) do
    quote do
      @behaviour Arca.Cli.Configurator.ConfiguratorBehaviour
      import Arca.Cli.Configurator.BaseConfigurator, only: [config: 2]

      # Register module attributes
      Module.register_attribute(__MODULE__, :app_name, accumulate: false)
      Module.register_attribute(__MODULE__, :commands, accumulate: false)
      Module.register_attribute(__MODULE__, :author, accumulate: false)
      Module.register_attribute(__MODULE__, :about, accumulate: false)
      Module.register_attribute(__MODULE__, :description, accumulate: false)
      Module.register_attribute(__MODULE__, :version, accumulate: false)
      Module.register_attribute(__MODULE__, :sorted, accumulate: false)

      # Default implementation
      def config, do: []

      defoverridable [config: 0]
    end
  end

  defmacro config(name, opts) do
    quote do
      Module.put_attribute(__MODULE__, :app_name, unquote(name))
      Module.put_attribute(__MODULE__, :commands, Keyword.get(unquote(opts), :commands, []))
      Module.put_attribute(__MODULE__, :author, Keyword.get(unquote(opts), :author, "Author"))
      Module.put_attribute(__MODULE__, :about, Keyword.get(unquote(opts), :about, "About"))
      Module.put_attribute(__MODULE__, :description, Keyword.get(unquote(opts), :description, "Description"))
      Module.put_attribute(__MODULE__, :version, Keyword.get(unquote(opts), :version, "0.1.0"))
      Module.put_attribute(__MODULE__, :sorted, Keyword.get(unquote(opts), :sorted, true))
    end
  end
end
```

### 4.4.3 Command Sorting

The command sorting system works at two levels:

1. In `BaseConfigurator` during command registration and processing:

```elixir
# Sort commands alphabetically if sorted is true (default)
defp maybe_sort_commands(commands) do
  if sorted() do
    # Ensure proper alphabetical ordering with case-insensitive comparison
    Enum.sort_by(commands, fn {cmd_name, _config} ->
      cmd_name |> to_string() |> String.downcase()
    end)
  else
    commands
  end
end

def inject_subcommands(optimus, commands \\ commands()) do
  # Process commands
  processed_commands =
    commands
    |> Enum.map(&get_command_config/1)
    |> maybe_sort_commands()

  # The rest of the inject_subcommands implementation...
end
```

2. In help text generation in `Arca.Cli`:

```elixir
# Check if sorting is enabled (default: true)
should_sort =
  case configurators() do
    [first_configurator | _] -> first_configurator.sorted()
    _ -> true  # Default to true if no configurators
  end

# Format the command list
command_list =
  visible_commands
  |> Enum.map(fn module ->
    {cmd_atom, opts} = apply(module, :config, []) |> List.first()
    name = Atom.to_string(cmd_atom)
    about = Keyword.get(opts, :about, "")
    {name, about}
  end)
  # Sort by name (alphabetically) if sorting is enabled
  |> maybe_sort_commands(should_sort)
  |> Enum.map(fn {name, about} ->
    padding = String.duplicate(" ", max(0, 20 - String.length(name)))
    "    #{name}#{padding}#{about}"
  end)
```

This implementation provides two command display modes:

1. **Alphabetical order** (default): Makes commands easier to find, especially as the command list grows
2. **Defined order**: Preserves the order in which commands were defined, useful for logical grouping or workflows

The command sorting is case-insensitive, ensuring that commands are properly ordered regardless of capitalization (e.g., "cfg.list" comes before "cli.history").

### 4.4.4 Configuration Coordination

The `Arca.Cli.Configurator.Coordinator` manages multiple configurators:

```elixir
defmodule Arca.Cli.Configurator.Coordinator do
  def setup(configurators) when is_list(configurators) do
    # Merge configurations from multiple configurators
  end

  def setup(configurator) do
    setup([configurator])
  end
end
```

### 4.4.5 Settings Management

User settings are managed through:

1. Default settings specified in configurators
2. Environment variable overrides
3. Persistent settings stored in a JSON file
4. Runtime updates through settings commands

## 4.5 Namespace Command System

### 4.5.1 Namespace Command Helper

The `Arca.Cli.Commands.NamespaceCommandHelper` provides a DSL for defining multiple commands in the same namespace:

```elixir
defmodule Arca.Cli.Commands.NamespaceCommandHelper do
  defmacro __using__(opts) do
    namespace = Keyword.get(opts, :namespace)

    quote do
      import Arca.Cli.Commands.NamespaceCommandHelper, only: [namespace_command: 3]
      @namespace unquote(namespace)
    end
  end

  defmacro namespace_command(name, about, do: block) do
    # Implementation of the DSL for namespace commands
  end
end
```

### 4.5.2 Namespace Command Example

Example usage of the namespace command helper:

```elixir
defmodule YourApp.Cli.Commands.User do
  use Arca.Cli.Commands.NamespaceCommandHelper, namespace: "user"

  namespace_command :profile, "Display user profile information" do
    "User profile information..."
  end

  namespace_command :settings, "Show user settings" do
    "User settings..."
  end
end
```

### 4.5.3 Dot Notation Parser

The system includes specialized parsing for dot notation commands:

```elixir
def parse_command(name) do
  parts = String.split(name, ".")

  case parts do
    [namespace, command] -> {:namespace, namespace, command}
    [command] -> {:command, command}
    _ -> {:error, :invalid_command_format}
  end
end
```

## 4.6 Utility Functions

### 4.6.1 String Utilities

The system includes various string manipulation utilities:

```elixir
defmodule Arca.Cli.Utils.Utils do
  def to_str(value) when is_binary(value), do: value
  def to_str(value) when is_atom(value), do: Atom.to_string(value)
  def to_str(value), do: inspect(value)

  def type_of(value) when is_binary(value), do: "string"
  def type_of(value) when is_integer(value), do: "integer"
  def type_of(value) when is_float(value), do: "float"
  def type_of(value) when is_boolean(value), do: "boolean"
  def type_of(value) when is_list(value), do: "list"
  def type_of(value) when is_map(value), do: "map"
  def type_of(value) when is_atom(value), do: "atom"
  def type_of(_value), do: "unknown"

  # Other utility functions...
end
```

### 4.6.2 Timer Utility

The system includes a timer utility for measuring execution time:

```elixir
def timer(fun) when is_function(fun, 0) do
  start = :os.timestamp()
  result = fun.()
  stop = :os.timestamp()
  duration = :timer.now_diff(stop, start) / 1_000_000
  {duration, result}
end
```
