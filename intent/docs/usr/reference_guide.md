---
verblock: "29 Oct 2025:v1.1: Matthew Sinclair - Added cli.script heredoc documentation
06 Oct 2025:v1.0: Claude - Added CLI Fixtures Testing documentation
17 Apr 2025:v0.9: Claude - Added error handling system documentation"
---

# Arca.Cli Reference Guide

This reference guide provides comprehensive information about the Arca.Cli system. Unlike the task-oriented User Guide, this reference guide serves as a complete reference for all aspects of the system.

## Table of Contents

1. [Command Reference](#command-reference)
2. [API Reference](#api-reference)
3. [Directory Structure](#directory-structure)
4. [Configuration Options](#configuration-options)
5. [Extension Points](#extension-points)
6. [Error Handling System](#error-handling-system)
7. [CLI Fixtures Testing](#cli-fixtures-testing)
8. [Concepts and Terminology](#concepts-and-terminology)

## Command Reference

### Standard Commands

#### `about`

Displays information about the CLI.

**Usage:**

```bash
arca_cli about
```

**Example Output:**

```
Arca.Cli v0.4.0
Copyright (c) 2024, Your Organization
```

#### `history`

Displays command history.

**Usage:**

```bash
arca_cli history
```

**Example Output:**

```
Command History:
1: about
2: sys.info
3: settings.all
```

#### `redo <index>`

Reruns a command from history.

**Usage:**

```bash
arca_cli redo <index>
```

**Parameters:**

- `index`: The index of the command in history (required)

**Example:**

```bash
arca_cli redo 2
```

#### `repl`

Enters interactive REPL mode.

**Usage:**

```bash
arca_cli repl
```

#### `settings.all`

Lists all configuration settings.

**Usage:**

```bash
arca_cli settings.all
```

#### `settings.get <id>`

Gets a specific setting.

**Usage:**

```bash
arca_cli settings.get <id>
```

**Parameters:**

- `id`: Setting identifier (required)

**Example:**

```bash
arca_cli settings.get cli.history.max_size
```

#### `status`

Displays CLI status.

**Usage:**

```bash
arca_cli status
```

#### `sys.info`

Shows system information.

**Usage:**

```bash
arca_cli sys.info
```

#### `sys.flush`

Flushes system caches.

**Usage:**

```bash
arca_cli sys.flush
```

#### `sys.cmd <command>`

Executes a system command.

**Usage:**

```bash
arca_cli sys.cmd <command>
```

**Parameters:**

- `command`: The system command to execute (required)

**Example:**

```bash
arca_cli sys.cmd "ls -la"
```

#### `cli.script <file>`

Executes commands from a script file.

**Usage:**

```bash
arca_cli cli.script <file>
```

**Parameters:**

- `file`: Path to script file containing CLI commands (required)

**Script File Format:**

Script files contain one command per line. Lines starting with `#` are comments and are ignored. Blank lines are also ignored.

**Basic Example:**

```bash
# my_script.cli
# This is a comment
about
sys.info
status
```

**HEREDOC Support:**

Commands can include heredoc-style stdin injection for interactive commands:

```
command <<MARKER
input line 1
input line 2
MARKER
```

**HEREDOC Example:**

```bash
# interactive_script.cli
ll.play my_game <<EOF
Hello there!
What do you think?
/exit
EOF
```

**Features:**

- Execute multiple commands sequentially
- Comments with `#`
- Blank lines ignored
- HEREDOC syntax for stdin injection
- Multiple heredocs per script
- Whitespace preservation in heredocs
- Custom marker names (any alphanumeric string)

**Limitations:**

- Heredoc markers must be on their own line
- No nested heredocs
- No variable interpolation in v1
- Works with commands using standard Elixir `IO.gets/1`

**See Also:** Script Files and HEREDOC Syntax section for complete syntax reference.

### Development Commands

#### `dev.info`

Shows development information.

**Usage:**

```bash
arca_cli dev.info
```

#### `dev.deps`

Lists project dependencies.

**Usage:**

```bash
arca_cli dev.deps
```

## API Reference

### Context Module (`Arca.Cli.Ctx`)

The Context module provides a structured way to build command output.

#### Context Structure

```elixir
%Arca.Cli.Ctx{
  command: atom(),      # Command being executed
  args: map(),          # Parsed arguments
  options: map(),       # Command options
  output: list(),       # Structured output items
  errors: list(),       # Error messages
  status: atom(),       # :ok | :error | :warning | :pending
  cargo: map(),         # Command-specific data
  meta: map()           # Style, format, and other metadata
}
```

#### Core Functions

**`Ctx.new(command, settings)`**

Creates a new context for a command.

```elixir
ctx = Ctx.new(:my_command, settings)
```

**`Ctx.add_output(ctx, output_item)`**

Adds an output item to the context.

```elixir
ctx = Ctx.add_output(ctx, {:success, "Operation completed"})
```

**`Ctx.add_error(ctx, error_message)`**

Adds an error message to the context.

```elixir
ctx = Ctx.add_error(ctx, "File not found")
```

**`Ctx.complete(ctx, status)`**

Marks the context as complete with a final status.

```elixir
ctx = Ctx.complete(ctx, :ok)  # or :error, :warning
```

**`Ctx.put_cargo(ctx, key, value)`** / **`Ctx.get_cargo(ctx, key)`**

Stores and retrieves command-specific data.

```elixir
ctx = Ctx.put_cargo(ctx, :user_count, 42)
count = Ctx.get_cargo(ctx, :user_count)
```

#### Output Item Types

**Messages**

```elixir
{:success, message}  # Green checkmark in ANSI mode
{:error, message}    # Red X in ANSI mode
{:warning, message}  # Yellow warning symbol in ANSI mode
{:info, message}     # Cyan info symbol in ANSI mode
{:text, content}     # Plain text
```

**Tables**

```elixir
# With explicit headers (columns in header order)
{:table, rows, headers: ["Name", "Age", "City"]}

# Override column order
{:table, rows,
  headers: ["Name", "Age", "City"],
  column_order: ["City", "Age", "Name"]
}

# First row as headers (preserves row order)
{:table, [headers_row | data_rows], has_headers: true}

# Alphabetical column order (default when no headers/column_order)
{:table, rows, []}

# Descending alphabetical
{:table, rows, column_order: :desc}

# Ascending alphabetical
{:table, rows, column_order: :asc}

# Custom sort function (by column name length)
{:table, rows, column_order: fn a, b -> String.length(a) <= String.length(b) end}

# Headerless table (no header row or auto-generated "Col1", "Col2" labels)
{:table, rows, show_headers: false}

# Headerless table with no borders
{:table, rows, show_headers: false, border_style: :none}
```

**Table Options:**

- `headers`: List of column header names (also sets column order)
- `column_order`: Explicit column ordering. Can be:
  - List of column names in desired order
  - `:asc` for ascending alphabetical order
  - `:desc` for descending alphabetical order
  - Custom comparison function `(column, column -> boolean())`
- `has_headers`: Boolean, treats first row as headers (default: true for AnsiRenderer, false for PlainRenderer)
- `show_headers`: Boolean, controls header row visibility (default: true)
  - When `false`, suppresses header row rendering (no "Col1", "Col2", no empty row)
  - Automatically sets `has_headers: false` for list rows to prevent first row being treated as headers
- `border_style`: `:solid`, `:solid_rounded`, `:none`, `:double`
- `divide_body_rows`: Boolean, add lines between rows
- `padding_x`: Integer, horizontal padding in cells
- `max_column_widths`: Function or map for column width limits
- `word_wrap`: `:break_word` or `:normal`
- `truncate_lines`: Boolean, truncate lines at max width
- `filter_columns`: Function to filter which columns to display

**Lists**

```elixir
# Simple list
{:list, ["Item 1", "Item 2", "Item 3"]}

# List with title
{:list, items, title: "Available Options"}

# List with custom bullet color (ANSI mode)
{:list, items, bullet_color: :green}
```

**Interactive Elements (ANSI mode only)**

```elixir
# Spinner
{:spinner, "Loading data", fn ->
  result = perform_operation()
  {:ok, result}
end}

# Progress indicator
{:progress, "Processing files", fn ->
  result = process_files()
  {:ok, result}
end}
```

### Output Module (`Arca.Cli.Output`)

The Output module handles rendering of contexts to different formats.

**`Output.render(ctx)`**

Renders a context to a string using the appropriate style.

```elixir
output = Arca.Cli.Output.render(ctx)
IO.puts(output)
```

**Style Detection**

The output style is automatically determined:

1. Plain style if `MIX_ENV=test`
2. Plain style if `NO_COLOR=1`
3. Style from `ARCA_STYLE` environment variable (ansi, plain, json, dump)
4. Plain style if not a TTY
5. ANSI style otherwise (default for interactive terminals)

### Renderers

**AnsiRenderer** - Colored output with formatting

- Green checkmarks for success
- Red X for errors
- Yellow warnings
- Cyan info messages
- Rounded borders for tables
- Colored bullet points for lists

**PlainRenderer** - No ANSI codes

- Simple symbols (✓, ✗, ⚠)
- Box-drawing characters for tables
- Plain bullet points for lists
- Suitable for tests and non-TTY environments

**JsonRenderer** - JSON structured output

- Outputs context as JSON
- Useful for programmatic consumption

**DumpRenderer** - Raw data inspection

- Shows internal structure
- Useful for debugging

### Command Definition

Commands are defined using the `Arca.Cli.Command.BaseCommand` module:

```elixir
defmodule YourApp.Cli.Commands.GreetCommand do
  use Arca.Cli.Command.BaseCommand

  config :greet,
    name: "greet",
    about: "Greet the user",
    args: [
      name: [
        value_name: "NAME",
        help: "Name to greet",
        required: true,
        parser: :string
      ]
    ]

  @impl true
  def handle(args, _settings, _optimus) do
    "Hello, #{args.args.name}!"
  end
end
```

### Context-Based Command Definition

Commands can return structured output using the Context system:

```elixir
defmodule YourApp.Cli.Commands.UserCommand do
  use Arca.Cli.Command.BaseCommand
  alias Arca.Cli.Ctx

  config :user,
    name: "user",
    about: "Display user information",
    args: [
      username: [
        value_name: "USERNAME",
        help: "Username to lookup",
        required: true,
        parser: :string
      ]
    ]

  @impl true
  def handle(args, settings, _optimus) do
    username = args.args.username

    Ctx.new(:user, settings)
    |> fetch_user_data(username)
    |> format_output()
    |> Ctx.complete(:ok)
  end

  defp fetch_user_data(ctx, username) do
    case Database.get_user(username) do
      {:ok, user} ->
        Ctx.put_cargo(ctx, :user, user)

      {:error, reason} ->
        ctx
        |> Ctx.add_error("User not found: #{reason}")
        |> Ctx.complete(:error)
    end
  end

  defp format_output(%Ctx{status: :error} = ctx), do: ctx
  defp format_output(%Ctx{cargo: %{user: user}} = ctx) do
    ctx
    |> Ctx.add_output({:success, "User found: #{user.name}"})
    |> Ctx.add_output({:table, [user], headers: ["id", "name", "email", "created_at"]})
  end
end
```

### Namespaced Command Definition

Using the NamespaceCommandHelper for multiple related commands:

```elixir
defmodule YourApp.Cli.Commands.User do
  use Arca.Cli.Commands.NamespaceCommandHelper

  namespace_command :profile, "Display user profile information" do
    "User profile information..."
  end

  namespace_command :settings, "Show user settings" do
    "User settings..."
  end
end
```

### Configurator Definition

Configurators register commands with Arca.Cli:

```elixir
defmodule YourApp.Cli.Configurator do
  use Arca.Cli.Configurator.BaseConfigurator

  config :your_app_cli,
    commands: [
      YourApp.Cli.Commands.GreetCommand,
      YourApp.Cli.Commands.UserProfileCommand,
    ],
    author: "Your Name",
    about: "Your CLI application",
    description: "A CLI tool for your application",
    version: "1.0.0",
    sorted: true  # Optional, defaults to true - sorts commands alphabetically
end
```

### Help System Configuration

Commands can control their help behavior by setting the `show_help_on_empty` option:

```elixir
defmodule YourApp.Cli.Commands.QueryCommand do
  use Arca.Cli.Command.BaseCommand

  config :query,
    name: "query",
    about: "Query data from the system",
    show_help_on_empty: true,  # Show help when invoked without arguments
    args: [
      id: [
        value_name: "ID",
        help: "ID to query",
        required: true,
        parser: :string
      ]
    ]

  @impl true
  def handle(args, settings, optimus) do
    # Command logic - help is handled automatically
    execute_query(args.args.id, settings)
  end
end
```

Setting `show_help_on_empty: true` causes the command to show help when invoked without arguments.
Setting `show_help_on_empty: false` (the default) lets the command execute normally without arguments.

### Configuration System

Arca.Cli uses the Arca.Config library for configuration management. The updated implementation includes Registry integration, file watching, and a callback system:

```elixir
# Loading settings (internal implementation)
def load_settings() do
  case Arca.Config.Server.reload() do
    {:ok, _} -> {:ok, true}
    {:error, reason} -> {:error, reason}
  end
end

# Retrieving a setting
def get_setting(setting_id) do
  case Arca.Config.get(setting_id) do
    {:ok, value} -> {:ok, value}
    {:error, :not_found} -> {:error, "Setting not found: #{setting_id}"}
    {:error, reason} -> {:error, "Error retrieving setting: #{inspect(reason)}"}
  end
end

# Saving settings
def save_settings(settings) do
  Enum.reduce_while(settings, {:ok, []}, fn {key, value}, {:ok, acc} ->
    case Arca.Config.put(key, value) do
      {:ok, _} -> {:cont, {:ok, [{key, value} | acc]}}
      error -> {:halt, error}
    end
  end)
end

# Registering for configuration changes
def register_for_changes(component_id, callback_fn) do
  Arca.Config.register_change_callback(component_id, callback_fn)
end

# Subscribing to specific config key changes
def subscribe_to_key_changes(key_path) do
  Arca.Config.subscribe(key_path)
end
```

The Registry integration provides better process isolation and resiliency, while file watching enables automatic reloading of configuration when changes are detected.

#### Configuration File Path Determination

Arca.Config automatically determines the configuration file paths based on the hosting application's name:

```elixir
# Example of how configuration file paths are determined
defp determine_config_path do
  # Get the application name
  app_name = Application.get_application(__MODULE__) |> Atom.to_string()

  # Check for application-specific environment variable override
  app_env_prefix = String.upcase(app_name)
  config_dir = System.get_env("#{app_env_prefix}_CONFIG_PATH") || ".#{app_name}/"

  # Get config filename from env or use default
  config_filename = System.get_env("#{app_env_prefix}_CONFIG_FILE") || "config.json"

  Path.join([config_dir, config_filename])
end
```

By default, if no environment variables are set:

1. The configuration directory will be `.app_name/` in the current directory (e.g., `.arca_cli/` for the `arca_cli` application)
2. The configuration file will be named `config.json`

## Directory Structure

```
lib/
├── arca_cli.ex             # Main entry point
├── arca_cli/               # Core modules
│   ├── commands/           # Built-in commands
│   │   ├── about_command.ex
│   │   ├── base_command.ex
│   │   ├── base_sub_command.ex
│   │   ├── command_behaviour.ex
│   │   └── ...
│   ├── configurator/       # Configuration modules
│   │   ├── base_configurator.ex
│   │   ├── configurator_behaviour.ex
│   │   ├── coordinator.ex
│   │   └── dft_configurator.ex
│   ├── help.ex             # Centralized help system
│   ├── history/            # Command history modules
│   │   └── history.ex
│   ├── repl/               # REPL modules
│   │   └── repl.ex
│   ├── supervisor/         # Supervision modules
│   │   └── history_supervisor.ex
│   └── utils/              # Utility functions
│       └── utils.ex
└── mix/                    # Mix tasks
    └── tasks/
        └── arca_cli.ex
```

## Configuration Options

### Environment Variables

| Variable             | Description                  | Default                       |
| -------------------- | ---------------------------- | ----------------------------- |
| APP_NAME_CONFIG_PATH | Configuration directory path | .app_name/ (e.g., .arca_cli/) |
| APP_NAME_CONFIG_FILE | Configuration filename       | config.json                   |

Note: The actual environment variable names are derived from the application name. For example, for the `arca_cli` application, the environment variables would be `ARCA_CLI_CONFIG_PATH` and `ARCA_CLI_CONFIG_FILE`.

### Application Configuration

In `config/config.exs`:

```elixir
config :arca_cli, :configurators, [
  YourApp.Cli.Configurator,
  Arca.Cli.Configurator.DftConfigurator
]

# Arca.Config registry settings
config :arca_config,
  parent_app: :your_app,         # Optional, defaults to the current application name
  default_config_path: "/path",  # Optional, defaults to ".{app_name}/"
  default_config_file: "config.json", # Optional, defaults to "config.json"
  watch_file: true,              # Enable file watching
  watch_interval: 1000           # Check file changes every 1000ms
```

### Command Configuration

Available command configuration options:

| Option             | Description                                                            | Type         |
| ------------------ | ---------------------------------------------------------------------- | ------------ |
| name               | Command name                                                           | String       |
| about              | Short description                                                      | String       |
| description        | Detailed description                                                   | String       |
| args               | Command arguments                                                      | Keyword list |
| options            | Command options                                                        | Keyword list |
| flags              | Command flags                                                          | Keyword list |
| hidden             | Whether command is hidden in help                                      | Boolean      |
| show_help_on_empty | Whether to show help when invoked without args                         | Boolean      |
| sorted             | Whether commands should be sorted alphabetically (configurator option) | Boolean      |

## Extension Points

### Creating Custom Commands

1. Define a command module that uses `Arca.Cli.Command.BaseCommand`
2. Implement the `handle/3` callback
3. Register the command in a configurator

### Creating Custom Configurators

1. Define a configurator module that uses `Arca.Cli.Configurator.BaseConfigurator`
2. Define your CLI configuration using the `config` macro
3. Register the configurator in your application config

### Adding Subcommands

1. Define a parent command module
2. Define subcommand modules that use `Arca.Cli.Command.BaseSubCommand`
3. Register the parent command in a configurator

### Customizing Help Display

The help system can be extended through callbacks:

1. Register a callback for `:format_help` using `Arca.Cli.Callbacks.register/2`
2. Implement a formatting function that transforms the help text
3. Return a modified help display

Example:

```elixir
# Check if the callbacks system is available
if Code.ensure_loaded?(Arca.Cli.Callbacks) do
  # Register a callback for format_help
  Arca.Cli.Callbacks.register(:format_help, fn help_text ->
    # Add branding or customize the help display
    branded_help = ["MyApp CLI Help:" | help_text]

    # Apply custom styling
    styled_help = Enum.map(branded_help, &MyApp.Formatters.colorize/1)

    # Return the formatted help
    {:halt, styled_help}
  end)
end
```

### Customizing Output Formatting

Arca.Cli includes a callback system that allows external applications to customize output formatting:

1. Register a callback for `:format_output` using `Arca.Cli.Callbacks.register/2`
2. Implement a formatting function that transforms the output
3. Return either a formatted string, `{:cont, value}` to continue the callback chain, or `{:halt, result}` to stop the chain

Example:

```elixir
# Check if the callbacks system is available
if Code.ensure_loaded?(Arca.Cli.Callbacks) do
  # Register a callback for format_output
  Arca.Cli.Callbacks.register(:format_output, fn output ->
    # Format the output as needed
    formatted = format_result(output)

    # Stop processing and use this result
    {:halt, formatted}
  end)
end
```

### Configuration Change Reactions

The updated Arca.Cli integrates with Arca.Config's callback system to react to configuration changes:

```elixir
# Register for all configuration changes
if Code.ensure_loaded?(Arca.Config) && function_exported?(Arca.Config, :register_change_callback, 2) do
  Arca.Config.register_change_callback(:my_component, fn config ->
    # React to configuration changes
    Logger.info("Configuration updated: #{inspect(config)}")
    apply_new_configuration(config)
  end)
end

# Subscribe to specific configuration key changes
if Code.ensure_loaded?(Arca.Config) && function_exported?(Arca.Config, :subscribe, 1) do
  Arca.Config.subscribe("app.feature.enabled")

  # In a process (such as a GenServer), handle the subscription messages:
  def handle_info({:config_updated, "app.feature.enabled", true}, state) do
    # Enable feature
    {:noreply, %{state | feature_enabled: true}}
  end

  def handle_info({:config_updated, "app.feature.enabled", false}, state) do
    # Disable feature
    {:noreply, %{state | feature_enabled: false}}
  end
end
```

## Error Handling System

The Arca CLI includes a comprehensive error handling system designed to provide consistent and informative error messages across all parts of the application.

### Error Handler Module

The `Arca.Cli.ErrorHandler` module provides the core functionality for the error handling system:

```elixir
defmodule Arca.Cli.ErrorHandler do
  @type error_type :: :command_not_found | :command_failed | :invalid_argument | # ...

  @type debug_info :: %{
    stack_trace: list() | nil,
    error_location: String.t() | nil,
    original_error: any() | nil,
    timestamp: DateTime.t()
  }

  @type enhanced_error :: {:error, error_type(), String.t(), debug_info() | nil}

  # Creates an enhanced error tuple with debug information
  @spec create_error(error_type(), String.t(), Keyword.t()) :: enhanced_error()
  def create_error(error_type, reason, opts \\ []) do
    # Implementation details
  end

  # Formats errors for display, optionally including debug information
  @spec format_error(
    enhanced_error() | {:error, error_type(), String.t()} | {:error, String.t()} | any(),
    Keyword.t()
  ) :: String.t()
  def format_error(error, opts \\ []) do
    # Implementation details
  end

  # Normalizes different error formats to the enhanced format
  @spec normalize_error(
    {:error, error_type(), String.t()} | {:error, String.t()} | any(),
    Keyword.t()
  ) :: enhanced_error() | any()
  def normalize_error(error, opts \\ []) do
    # Implementation details
  end

  # Converts an enhanced error to a standard error (for backward compatibility)
  @spec to_standard_error(enhanced_error()) :: {:error, error_type(), String.t()}
  def to_standard_error({:error, error_type, reason, _debug_info}) do
    {:error, error_type, reason}
  end

  # Converts an enhanced or standard error to a legacy error
  @spec to_legacy_error(enhanced_error() | {:error, error_type(), String.t()}) :: {:error, String.t()}
  def to_legacy_error({:error, _error_type, reason, _debug_info}) do
    {:error, reason}
  end
end
```

### Debug Mode Command

The `cli.debug` command allows users to toggle detailed error information:

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

### Standard Error Types

The system defines standardized error types for consistent error classification:

| Error Type           | Description                                              |
| -------------------- | -------------------------------------------------------- |
| `:command_not_found` | No command was found matching the given name             |
| `:command_failed`    | A command failed during execution                        |
| `:invalid_argument`  | An invalid argument was provided to a command            |
| `:config_error`      | An error occurred in the configuration system            |
| `:file_not_found`    | A requested file could not be found                      |
| `:file_not_readable` | A file exists but cannot be read due to permissions      |
| `:file_not_writable` | A file cannot be written to due to permissions           |
| `:decode_error`      | Error decoding data (e.g., JSON parsing)                 |
| `:encode_error`      | Error encoding data (e.g., JSON serialization)           |
| `:validation_error`  | Command validation failed                                |
| `:command_mismatch`  | Command name mismatch between registration and execution |
| `:help_requested`    | User requested help for a command                        |
| `:unknown_error`     | Unclassified error without a specific type               |

### Enhanced Error Format

The enhanced error format provides comprehensive error information:

```elixir
{:error, :command_failed, "Failed to execute command", %{
  stack_trace: [
    {Arca.Cli.Commands.ExampleCommand, :handle, 3, [file: "lib/arca_cli/commands/example_command.ex", line: 25]},
    {Arca.Cli, :execute_command, 5, [file: "lib/arca_cli.ex", line: 672]},
    {Arca.Cli, :handle_subcommand, 4, [file: "lib/arca_cli.ex", line: 614]},
    {Arca.Cli, :main, 1, [file: "lib/arca_cli.ex", line: 233]}
  ],
  error_location: "Arca.Cli.Commands.ExampleCommand.handle/3",
  original_error: %RuntimeError{message: "Something went wrong"},
  timestamp: ~U[2025-04-17 15:30:45.123Z]
}}
```

When debug mode is enabled, the formatted output includes this detailed information:

```
Error (command_failed): Failed to execute command
Debug Information:
  Time: 2025-04-17 15:30:45.123Z
  Location: Arca.Cli.Commands.ExampleCommand.handle/3
  Original error: %RuntimeError{message: "Something went wrong"}
  Stack trace:
    Elixir.Arca.Cli.Commands.ExampleCommand.handle/3 (lib/arca_cli/commands/example_command.ex:25)
    Elixir.Arca.Cli.execute_command/5 (lib/arca_cli.ex:672)
    Elixir.Arca.Cli.handle_subcommand/4 (lib/arca_cli.ex:614)
    Elixir.Arca.Cli.main/1 (lib/arca_cli.ex:233)
```

### Using Error Handling in Custom Commands

When implementing custom commands, you can leverage the error handling system:

```elixir
defmodule YourApp.Cli.Commands.CustomCommand do
  use Arca.Cli.Command.BaseCommand
  alias Arca.Cli.ErrorHandler

  config :custom,
    name: "custom",
    about: "Example custom command"

  @impl true
  def handle(_args, _settings, _optimus) do
    case perform_operation() do
      {:ok, result} ->
        # Success case
        result

      {:error, reason} when is_binary(reason) ->
        # Convert legacy error to enhanced error
        ErrorHandler.create_error(
          :command_failed,
          reason,
          error_location: "#{__MODULE__}.handle/3"
        )

      error = {:error, _type, _reason} ->
        # Already using standard error format, convert to enhanced
        ErrorHandler.normalize_error(error, error_location: "#{__MODULE__}.handle/3")

      error = {:error, _type, _reason, _debug} ->
        # Already using enhanced format
        error
    end
  rescue
    e ->
      # Create enhanced error with stack trace
      ErrorHandler.create_error(
        :command_failed,
        "Custom command failed: #{Exception.message(e)}",
        stack_trace: __STACKTRACE__,
        original_error: e,
        error_location: "#{__MODULE__}.handle/3"
      )
  end

  defp perform_operation do
    # Your implementation...
  end
end
```

### Error Handler Testing

When testing commands that use the error handling system:

```elixir
defmodule YourApp.Test.CustomCommandTest do
  use ExUnit.Case
  import ExUnit.CaptureIO

  test "handle/3 returns enhanced error tuple for invalid input" do
    result = YourApp.Cli.Commands.CustomCommand.handle(
      %{args: %{value: "invalid"}},
      %{},
      nil
    )

    # Test the error structure
    assert {:error, :invalid_argument, "Invalid value", debug_info} = result
    assert is_map(debug_info)
    assert debug_info.error_location == "YourApp.Cli.Commands.CustomCommand.handle/3"

    # Test the formatted output with debug enabled
    Application.put_env(:arca_cli, :debug_mode, true)
    output = capture_io(fn ->
      Arca.Cli.ErrorHandler.format_error(result, debug: true)
      |> IO.puts()
    end)

    assert output =~ "Error (invalid_argument): Invalid value"
    assert output =~ "Debug Information:"
    assert output =~ "Location: YourApp.Cli.Commands.CustomCommand.handle/3"
  end
end
```

### Error Handling Macros

The error handling system includes macros to simplify the creation and formatting of errors with automatic location tracking:

```elixir
defmodule Arca.Cli.ErrorHandler do
  # Existing functions...

  defmacro __using__(_) do
    quote do
      import Arca.Cli.ErrorHandler, only: [create_and_format_error: 2, create_and_format_error: 3]
    end
  end

  @doc """
  Creates and formats an error with automatic location tracking.

  This macro automatically adds the current module and function name
  to the error location, simplifying error creation and formatting
  in a single operation.
  """
  defmacro create_and_format_error(error_type, message, opts \\ []) do
    quote do
      error_location = "#{__MODULE__}.#{elem(__ENV__.function, 0)}/#{elem(__ENV__.function, 1)}"

      unquote(opts)
      |> Keyword.put(:error_location, error_location)
      |> (&Arca.Cli.ErrorHandler.create_error(unquote(error_type), unquote(message), &1)).()
      |> Arca.Cli.ErrorHandler.format_error()
    end
  end
end
```

Using this macro in your commands dramatically simplifies error handling:

```elixir
defmodule YourApp.Cli.Commands.ExampleCommand do
  use Arca.Cli.Command.BaseCommand
  use Arca.Cli.ErrorHandler  # Import the error handling macros

  config :example,
    name: "example",
    about: "Example command"

  @impl true
  def handle(args, _settings, _optimus) do
    case validate_args(args) do
      :ok ->
        execute_command(args)

      {:error, reason} ->
        # Use the macro for simplified error handling
        create_and_format_error(:validation_error, reason)
    end
  end

  defp validate_args(%{args: %{limit: limit}}) when not is_integer(limit) or limit <= 0 do
    {:error, "Limit must be a positive integer"}
  end

  defp validate_args(_), do: :ok

  defp execute_command(args) do
    # Command implementation
  end
end
```

The benefits of using the macro include:

1. **Automatic location tracking**: No need to manually construct error locations
2. **Reduced boilerplate**: Single function call instead of multiple steps
3. **Consistent formatting**: Ensures all errors are handled similarly
4. **Less error-prone**: Eliminates potential errors in manual location construction

### Planned Future Enhancements

Future versions of the error handling system may include:

1. Command-specific error handling protocols
2. ANSI color formatting for improved readability
3. Interactive debugging capabilities
4. Clickable file paths in terminal output
5. Additional error handling macros for specialized use cases

## CLI Fixtures Testing

Arca.Cli includes a powerful declarative testing framework for CLI commands using file-based fixtures. This system makes it easy to create integration tests without writing verbose test code.

### Overview

The `Arca.Cli.Testing.CliFixturesTest` module provides:

- **Declarative testing**: Define tests using simple file structures
- **Auto-discovery**: Tests are automatically discovered and generated from fixture directories
- **Pattern matching**: Flexible output validation with wildcards and patterns
- **Setup/teardown**: Both CLI-based (`.cli`) and Elixir-based (`.exs`) setup and teardown
- **Variable interpolation**: Share data between setup, commands, and assertions using `{{variable}}` syntax
- **Test isolation**: Each fixture runs in a clean environment

### Basic Usage

Add the testing module to your test file:

```elixir
defmodule MyApp.CliFixturesTest do
  use ExUnit.Case, async: false
  use Arca.Cli.Testing.CliFixturesTest

  # Tests are automatically discovered and generated!
end
```

### Fixture Directory Structure

Fixtures are organized hierarchically:

```
test/cli/fixtures/
  <command.name>/              # e.g., "about", "config.set"
    001/                       # Test variation (001-999)
      setup.exs                # OPTIONAL: Elixir setup (returns bindings)
      setup.cli                # OPTIONAL: CLI setup commands
      cmd.cli                  # REQUIRED: Command to test
      expected.out             # OPTIONAL: Expected output
      teardown.cli             # OPTIONAL: CLI cleanup commands
      teardown.exs             # OPTIONAL: Elixir cleanup (receives bindings)
      skip                     # OPTIONAL: Mark test as skipped
```

### File Types

#### `cmd.cli` (REQUIRED)

The command to test. Only this command's output is validated.

```bash
# test/cli/fixtures/about/001/cmd.cli
about
```

#### `expected.out` (OPTIONAL)

Expected output from `cmd.cli`. Supports pattern matching and variable interpolation.

```
# Exact match
📦 Arca CLI
A declarative CLI for Elixir apps

# With patterns
Status: {{*}}
Count: {{\\d+}}

# With variable interpolation
User: {{user_name}}
ID: {{user_id}}
```

#### `setup.cli` (OPTIONAL)

Commands to run before `cmd.cli`. Output is ignored. Supports variable interpolation.

```bash
# test/cli/fixtures/example/001/setup.cli
config.reset
config.set theme {{theme_name}}
```

#### `teardown.cli` (OPTIONAL)

Commands to run after `cmd.cli` (always runs, even on failure). Supports variable interpolation.

```bash
# test/cli/fixtures/example/001/teardown.cli
config.reset
```

#### `setup.exs` (OPTIONAL - Advanced)

Elixir script for programmatic setup. Must return a map of bindings.

```elixir
# test/cli/fixtures/auth.login/001/setup.exs
alias MyApp.Accounts.{User, ApiKey}

# Create test user
{:ok, user} =
  User
  |> Ash.Changeset.for_create(:create, %{
    email: "test@example.com",
    password: "testpass123"
  }, authorize?: false)
  |> Ash.create()

# Generate API key
{:ok, api_key_record} =
  ApiKey
  |> Ash.Changeset.for_create(:create, %{
    user_id: user.id,
    expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)
  }, authorize?: false)
  |> Ash.create()

# Return bindings for interpolation
%{
  user_email: user.email,
  user_id: user.id,
  api_key: api_key_record.__metadata__.plaintext_api_key
}
```

**Requirements:**

- Must return a map: `%{atom_key: value}`
- Has access to all application modules
- Runs in test environment only
- Should use `authorize?: false` to bypass authorization

#### `teardown.exs` (OPTIONAL - Advanced)

Elixir script for cleanup. Receives bindings from `setup.exs`.

```elixir
# test/cli/fixtures/auth.login/001/teardown.exs
alias MyApp.Accounts.User

user_id = bindings[:user_id]

if user_id do
  User
  |> Ash.get!(user_id, authorize?: false)
  |> Ash.destroy!(authorize?: false)
end
```

**Best Practice:** Always check if bindings exist before using them.

### Variable Interpolation

Variables from `setup.exs` can be interpolated into all `.cli` and `.out` files using `{{variable}}` syntax.

**Execution flow:**

1. `setup.exs` → returns `%{user_id: 123, api_key: "abc"}`
2. `setup.cli` → can use `{{user_id}}` and `{{api_key}}`
3. `cmd.cli` → can use `{{user_id}}` and `{{api_key}}`
4. `expected.out` → can use `{{user_id}}` and `{{api_key}}`
5. `teardown.cli` → can use `{{user_id}}` and `{{api_key}}`
6. `teardown.exs` → receives `bindings[:user_id]` and `bindings[:api_key]`

**Type conversion:** All values are converted to strings using `to_string/1`.

**Missing bindings:** Unknown variables are left as literal `{{key}}` (graceful degradation).

### Pattern Matching

Pattern matchers are preserved during variable interpolation:

| Pattern                | Description         | Example Match              |
| ---------------------- | ------------------- | -------------------------- |
| `{{*}}`                | Non-greedy wildcard | Matches any text (minimal) |
| `{{.*}}`               | Greedy wildcard     | Matches any text (maximal) |
| `{{??}}` or `{{\\d+}}` | Digits              | `123`, `42`                |
| `{{\\w+}}`             | Word characters     | `user_name`, `abc123`      |

**Example combining variables and patterns:**

```
# expected.out
User: {{user_email}}      # Variable interpolation
Created: {{*}}            # Pattern matcher
ID: {{\\d+}}              # Pattern matcher
```

### Complete Example

```elixir
# test/cli/fixtures/site.show/001/setup.exs
{:ok, site} = create_test_site("mysite", "My Site")
{:ok, api_key} = generate_api_key()

%{
  site_subdomain: site.subdomain,
  site_name: site.name,
  site_id: site.id,
  api_key: api_key.plaintext
}
```

```bash
# test/cli/fixtures/site.show/001/setup.cli
laksa.auth.login --api-key "{{api_key}}"
```

```bash
# test/cli/fixtures/site.show/001/cmd.cli
laksa.site.show {{site_subdomain}}
```

```
# test/cli/fixtures/site.show/001/expected.out
Site: {{site_subdomain}}
subdomain | {{site_subdomain}}
name      | {{site_name}}
status    | {{*}}
```

```elixir
# test/cli/fixtures/site.show/001/teardown.exs
site_id = bindings[:site_id]

if site_id do
  Site
  |> Ash.get!(site_id, authorize?: false)
  |> Ash.destroy!(authorize?: false)
end
```

### When to Use `.exs` vs `.cli`

**Use `.exs` files when:**

- Creating database records directly (faster than CLI)
- Generating tokens or computed values
- Complex setup requiring Elixir logic
- Need to return data for interpolation

**Use `.cli` files when:**

- Testing CLI workflow end-to-end
- Setup is simple and command-based
- Want to test the full command stack

**Best Practice:** Mix both - use `.exs` for data setup, `.cli` for command-based setup.

### Test Isolation

Each fixture test runs in complete isolation:

- Unique temporary config directory
- Clean state (no shared data between tests)
- Automatic cleanup after test completes
- Teardown always runs (even on test failure)

### API Reference

#### `discover_fixtures/0`

Discovers all fixtures in `test/cli/fixtures/`. Called at compile time.

#### `run_fixture/3`

Orchestrates the full test lifecycle:

1. Run `setup.exs` → get bindings
2. Run `setup.cli` with interpolation
3. Run `cmd.cli` with interpolation
4. Compare output with `expected.out` (with interpolation)
5. Run `teardown.cli` with interpolation
6. Run `teardown.exs` with bindings

#### `interpolate_bindings/2`

```elixir
interpolate_bindings(content, bindings)
```

Replaces `{{variable}}` placeholders while preserving pattern matchers.

#### `run_setup_script/1`

```elixir
run_setup_script(fixture_path) :: {:ok, map()}
```

Evaluates `setup.exs` and returns bindings map. Returns `{:ok, %{}}` if file doesn't exist.

#### `run_teardown_script/2`

```elixir
run_teardown_script(fixture_path, bindings) :: :ok
```

Evaluates `teardown.exs` with bindings. Logs errors but always returns `:ok`.

### Troubleshooting

**"Missing cmd.cli"**

- Every fixture variation requires a `cmd.cli` file

**"Output mismatch"**

- Compare expected vs actual in error message
- Check for whitespace differences
- Try pattern matching for dynamic content

**"setup.exs must return a map"**

- Ensure `setup.exs` returns `%{key: value}`, not `{:ok, %{}}` or other tuples

**Variables not interpolating**

- Check variable name is valid: `[a-z_][a-z0-9_]*`
- Ensure `setup.exs` returns the variable in its map
- Verify syntax is `{{variable}}` not `{variable}`

**Teardown errors**

- Use defensive patterns: `if bindings[:key], do: cleanup()`
- Check for `nil` before using bindings

## Script Files and HEREDOC Syntax

The `cli.script` command supports executing multiple CLI commands from script files, including heredoc-style stdin injection for interactive commands.

### Script File Format

Script files use a simple line-based format:

```
# Comment lines start with #
command1
command2 arg1 arg2

# Blank lines are ignored

command3
```

**Rules:**

- One command per line
- Lines starting with `#` are comments (ignored)
- Blank lines are ignored
- Commands are executed sequentially
- Each command's output is displayed before next command runs

### HEREDOC Syntax Specification

HEREDOC allows injecting multiple lines of stdin input into commands that read user input.

**Basic Syntax:**

```
command <<MARKER
line 1
line 2
line 3
MARKER
```

**Components:**

1. **Start Marker**: `<<MARKER` at end of command line (must have space before `<<`)
2. **Content Lines**: Lines between markers (preserved verbatim)
3. **End Marker**: `MARKER` on its own line (must match start marker exactly)

**Processing:**

1. Each content line is sent to command's stdin as if user typed it + Enter
2. After last line, EOF is automatically sent (like Ctrl-D)
3. Command receives input via standard `IO.gets/1` calls

### Marker Names

**Valid Markers:**

- Must be alphanumeric plus underscore: `[a-zA-Z0-9_]+`
- Case-sensitive (EOF != eof)
- No length limit
- Convention: uppercase (EOF, END, DATA, INPUT)

**Examples:**

```
command <<EOF
command <<END
command <<DATA
command <<INPUT
command <<TEST123
command <<my_marker
```

**Invalid:**

```
command <<EOF!       # Special characters not allowed
command <<"EOF"      # Quotes not supported
command <<123        # Cannot start with digit
```

### Content Handling

**Whitespace Preservation:**

All whitespace in content lines is preserved exactly:

```
command <<SPACES
  two spaces
    four spaces
		tab character
trailing spaces
SPACES
```

Output includes all indentation and trailing whitespace.

**Empty Lines:**

Empty lines within heredoc are preserved:

```
command <<EMPTY
line 1

line 3
EMPTY
```

This sends: "line 1\n", "\n", "line 3\n"

**Special Characters:**

All characters are sent literally (no escaping):

```
command <<SPECIAL
$variable
`backticks`
"quotes"
\backslashes\
SPECIAL
```

### Multiple HEREDOC in One Script

Scripts can contain multiple heredoc sections:

```
# First command with stdin
command1 <<EOF
input for command1
EOF

# Regular command (no stdin)
command2

# Second command with stdin (different marker)
command3 <<DATA
input for command3
DATA

# Another regular command
command4
```

### Implementation Details

**Architecture:**

- **Parser**: Two-state machine (normal / in_heredoc)
- **InputProvider**: GenServer implementing Erlang IO protocol
- **Group Leader**: Redirects stdin to InputProvider during execution

**How It Works:**

1. Script file is parsed into command list
2. Heredocs detected and content captured
3. For commands with heredoc:
   - InputProvider GenServer started with lines
   - Process group leader temporarily swapped
   - Command executes (stdin requests go to provider)
   - Group leader restored after execution

**IO Protocol Support:**

Works with commands using:

- `IO.gets/1`, `IO.gets/2` - Get line of input
- `IO.getn/2`, `IO.getn/3` - Get N characters
- `IO.read/2` - Read input

May not work with:

- Custom IO libraries (ExPrompt, etc.)
- Direct stdin reading bypassing group leader
- Port-based external command execution

### Limitations and Known Issues

**Current Limitations (v1):**

1. **No Nested HEREDOC**: Cannot have heredoc within heredoc
2. **No Variable Interpolation**: No `{{variable}}` substitution
3. **Marker in Content**: If content contains marker word on its own line, heredoc ends early
4. **Single Marker**: Cannot use multiple markers for one command
5. **No Tab Stripping**: `-` prefix not supported (like `<<-EOF`)
6. **No Quote Escaping**: Cannot escape marker (like `<<'EOF'`)

**Workarounds:**

**Issue**: Content contains EOF marker

```
# Problem:
command <<EOF
This mentions EOF in text
EOF will close early!
EOF

# Solution: Use different marker
command <<ENDOFTEXT
This mentions EOF in text
EOF will close early!
ENDOFTEXT
```

**Issue**: Command doesn't use standard IO

```
# Some commands may not work - test first
# Check if command uses IO.gets/1
```

### Comparison with CLI Fixtures Testing

| Feature                | cli.script HEREDOC | CLI Fixtures `.cli` files |
| ---------------------- | ------------------ | ------------------------- |
| Variable interpolation | No                 | Yes (`{{var}}`)           |
| Pattern matching       | No                 | Yes (`{{*}}`, `{{\\d+}}`) |
| Setup/teardown         | No                 | Yes (`.exs` files)        |
| Bindings               | No                 | Yes (from `setup.exs`)    |
| Use case               | Script automation  | Automated testing         |
| Complexity             | Simple             | Full test framework       |

**When to Use:**

- **cli.script**: Quick automation, demos, manual workflows
- **CLI Fixtures**: Comprehensive testing with validation

### Examples

**Interactive Game:**

```
# game_session.cli
ll.world.mount fantasy_world
ll.play adventure <<SESSION
look around
take sword
go north
fight dragon
use sword
/exit
SESSION
```

**Agent Testing:**

```
# test_agent.cli
ll.agent.create test_agent <<CONFIG
personality: helpful
model: gpt-4
EOF

ll.agent.engage test_agent <<CONVERSATION
What is 2+2?
Explain photosynthesis
/done
CONVERSATION
```

**Batch Processing:**

```
# process_data.cli
data.import file1.csv
data.process <<OPTIONS
normalize
validate
transform
export
OPTIONS

data.import file2.csv
data.process <<OPTIONS
normalize
validate
transform
export
OPTIONS
```

### Error Handling

**Unclosed HEREDOC:**

```
command <<EOF
line 1
# Missing EOF marker

Error: Unclosed heredoc starting at line 2: expected 'EOF' but reached end of file
```

**Marker Mismatch:**

```
command <<EOF
line 1
END  # Wrong marker

Error: Unclosed heredoc starting at line 2: expected 'EOF' but reached end of file
```

**Command Failure:**

If command with heredoc fails, error is reported normally and script execution continues unless command exits with error.

### Best Practices

1. **Choose Descriptive Markers**: Use markers that indicate purpose (TEST, CONFIG, DATA)
2. **Avoid Common Words**: Don't use EOF if content might contain "EOF"
3. **Consistent Indentation**: Keep heredoc content flush left for readability
4. **Comment Your Scripts**: Explain what each heredoc does
5. **Test Interactive Commands**: Verify command works before scripting
6. **Keep Scripts Simple**: Use regular commands when heredoc isn't needed

## Concepts and Terminology

| Term                                  | Definition                                                                                  |
| ------------------------------------- | ------------------------------------------------------------------------------------------- |
| Command                               | A self-contained unit of functionality that can be executed from the CLI                    |
| Configurator                          | A module that registers commands and defines CLI configuration                              |
| REPL                                  | Read-Eval-Print Loop, an interactive shell for running commands                             |
| Dot Notation                          | A naming convention for organizing commands hierarchically (e.g., `sys.info`)               |
| NamespaceCommandHelper                | A helper module for defining multiple commands in the same namespace                        |
| BaseCommand                           | The base module for defining commands                                                       |
| BaseSubCommand                        | The base module for defining subcommands                                                    |
| Callbacks                             | Extension system allowing external applications to customize behavior                       |
| Callback Chain                        | Multiple callbacks executed in reverse registration order (last registered, first executed) |
| Registry                              | Elixir's built-in process registry, used by Arca.Config for process management              |
| File Watching                         | Mechanism to detect and automatically reload configuration file changes                     |
| Application-based Config              | The system of deriving configuration paths from the application name                        |
| Command Sorting                       | Feature that determines whether commands are displayed in alphabetical order                |
|                                       | (case-insensitive, default) or in the order they were defined                               |
| ErrorHandler                          | Central module for standardized error handling, formatting, and normalization               |
| Enhanced Error Tuple                  | Four-element error tuple with debug information: `{:error, error_type, reason, debug_info}` |
| Debug Mode                            | Optional mode that displays detailed error information including stack traces               |
| create_error_with_location            | Macro that creates errors with automatic location tracking                                  |
| create_and_format_error_with_location | Macro that creates and formats errors with automatic location tracking                      |
| err_cloc                              | Shorthand alias for create_error_with_location                                              |
| err_cfloc                             | Shorthand alias for create_and_format_error_with_location                                   |
