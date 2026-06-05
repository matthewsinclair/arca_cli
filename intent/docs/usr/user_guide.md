---
verblock: "29 Oct 2025:v1.1: Matthew Sinclair - Added cli.script heredoc documentation
06 Oct 2025:v1.0: Claude - Added CLI Fixtures Testing section
17 Apr 2025:v0.9: Claude - Added error handling and debug mode documentation"
---

# Arca.Cli User Guide

This user guide provides task-oriented instructions for using the Arca.Cli system. It explains how to accomplish common tasks and provides workflow guidance.

## Table of Contents

1. [Introduction](#introduction)
2. [Installation](#installation)
3. [Getting Started](#getting-started)
4. [Common Tasks](#common-tasks)
5. [Advanced Usage](#advanced-usage)
6. [Troubleshooting](#troubleshooting)

## Introduction

Arca.Cli is a flexible command-line interface utility for Elixir projects. It provides a robust framework for building and interacting with command-line applications.

### Purpose

Arca.Cli solves several common problems in CLI development:

- Provides a consistent framework for building command-line applications
- Reduces boilerplate code required for CLI functionality
- Offers built-in features like command history, REPL mode, and configuration management
- Makes it easy to organize and extend commands with namespaces

### Core Concepts

Arca.Cli is built around these fundamental concepts:

- **Commands**: Self-contained modules that implement specific functionality
- **Namespaced Commands**: Hierarchical organization using dot notation (e.g., `sys.info`)
- **REPL Mode**: Interactive shell with command history and tab completion
- **Configurators**: Modules that register commands and define CLI behavior
- **Callbacks**: Extension system allowing customization of output formatting
- **Configuration Management**: Registry-based configuration with file watching capabilities

## Installation

### Prerequisites

- Elixir and Erlang installed on your system
- Mix build tool
- A terminal with Unicode support

### Installation Steps

Add `arca_cli` to your project's dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:arca_cli, "~> 0.4.0"}
  ]
end
```

Run mix deps.get to install the dependency:

```bash
mix deps.get
```

## Getting Started

### First Steps

After installation, you can run the CLI with its built-in commands:

```bash
# Display information about the CLI
$ arca_cli about

# Show system information
$ arca_cli sys.info

# View command history
$ arca_cli history

# Enter interactive REPL mode
$ arca_cli repl
```

To see all available commands, use the help flag:

```bash
arca_cli --help
```

### Basic Workflow

The typical workflow with Arca.Cli involves:

1. Executing commands directly from your shell
2. Using the REPL mode for interactive sessions
3. Viewing command history and repeating previous commands
4. Managing configuration settings

## Common Tasks

### Getting Help

Arca.Cli provides consistent help in three ways:

1. **Command without arguments**: For commands that require arguments

   ```bash
   $ arca_cli settings.get
   error: settings.get: missing required arguments: SETTING_ID
   ```

2. **Using the --help flag**: Works with any command

   ```bash
   $ arca_cli settings.get --help
   Get a specific setting by ID.

   USAGE:
       cli settings.get SETTING_ID
   ```

3. **Using the help prefix**: Alternative way to access help

   ```bash
   $ arca_cli help settings.get
   Get a specific setting by ID.

   USAGE:
       cli settings.get SETTING_ID
   ```

The help system works consistently across both CLI and REPL modes, and will automatically detect when help should be shown.

### Using the REPL Mode

Starting REPL mode:

```bash
$ arca_cli repl
>
```

Once in REPL mode, you can:

1. **Execute Commands**: Type any available command to execute it

   ```
   > sys.info
   ```

2. **Tab Completion**: Press TAB to show available commands or complete a partial command

   ```
   > sys.[TAB]
   sys.cmd    sys.flush    sys.info
   ```

3. **Command History**: Use UP/DOWN arrow keys to navigate through previously executed commands

4. **Special Commands**:
   - `help`: Display available commands
   - `history`: View command history
   - `quit` or `exit`: Exit REPL mode

5. **Help in REPL**: Access help the same way as in CLI mode

   ```
   > settings.get --help
   ```

   or

   ```
   > help settings.get
   ```

### Managing Configuration

Viewing all settings:

```bash
arca_cli settings.all
```

Getting a specific setting:

```bash
arca_cli settings.get id
```

The configuration system now features real-time file watching, which means that edits made to the configuration file outside the application are automatically detected and loaded. This is useful for environments where configurations need to be updated without restarting the application.

#### Configuration File Paths

Arca.Cli and Arca.Config automatically determine the configuration paths based on the application name. By default:

- The configuration directory is set to `.app_name/` in the current directory (e.g., `.arca_cli/` for the `arca_cli` application)
- The configuration file is named `config.json`

These paths can be overridden with application-specific environment variables if needed:

```bash
# Example of custom configuration paths for the arca_cli application
export ARCA_CLI_CONFIG_PATH="/custom/path/to/config/dir/"
export ARCA_CLI_CONFIG_FILE="custom_config.json"
```

### Working with Command History

Viewing command history:

```bash
arca_cli history
```

Redoing a previous command:

```bash
arca_cli redo 3
```

### Executing System Commands

Running system commands:

```bash
arca_cli sys.cmd "ls -la"
```

Flushing system caches:

```bash
arca_cli sys.flush
```

### Running Script Files with cli.script

The `cli.script` command allows you to execute multiple CLI commands from a script file. This is useful for automation, testing, and repeatable workflows.

#### Basic Script Execution

Create a script file with commands (one per line):

```bash
# my_script.cli
# Lines starting with # are comments

about
sys.info
status
```

Run the script:

```bash
arca_cli cli.script my_script.cli
```

#### HEREDOC Syntax for Interactive Commands

When working with interactive commands that require stdin input (like `ll.play`, `ll.agent.engage`, or `ll.llm.chat`), you can use heredoc syntax to inject input automatically:

```
command <<MARKER
line 1
line 2
line 3
MARKER
```

**Basic Example:**

```
ll.play my_game <<EOF
Hello there!
What do you think?
/exit
EOF
```

Each line between `<<EOF` and `EOF` is fed to the command as if you typed it and pressed Enter.

**Multiple Interactions in One Script:**

```
# Setup
ll.world.mount my_world

# First interaction
ll.play game1 <<EOF
Start game
Make choice A
/exit
EOF

# Regular commands work too
status

# Second interaction
ll.agent.engage assistant <<DATA
analyze this data
show results
/done
DATA
```

**Custom Markers:**

You can use any alphanumeric marker name:

```
command <<END
input here
END

command <<INPUT
more input
INPUT

command <<DATA123
data here
DATA123
```

#### Heredoc Features and Limitations

**Features:**

- Whitespace is preserved exactly as written
- Multiple heredocs per script
- Works with any command using standard Elixir `IO.gets/1`
- Backward compatible (scripts without heredocs still work)
- Comments and blank lines work normally outside heredocs

**Limitations:**

- Marker must appear on its own line to close heredoc
- No nested heredocs
- No variable interpolation
- If heredoc content contains the marker word, choose a different marker
- Commands using custom IO implementations may not work

**Whitespace Preservation:**

```
command <<SPACES
  indented line
    more indentation
  tabbed line
SPACES
```

All leading and trailing whitespace is preserved exactly as written.

#### Use Cases

**Automated Testing:**

```
# test_scenario.cli
ll.world.mount test_world
ll.play test_game <<TEST
input A
input B
verify result
/exit
TEST
```

**Demo Scripts:**

```
# demo.cli
# Show features automatically
ll.feature.demo <<DEMO
Show feature 1
Show feature 2
Show feature 3
/exit
DEMO
```

**Batch Processing:**

```
# process_multiple.cli
process.item <<DATA
item1 data
DATA

process.item <<DATA
item2 data
DATA

process.item <<DATA
item3 data
DATA
```

## Advanced Usage

### Command Organization

Arca.Cli uses hierarchical command organization with dot notation:

```bash
# System-related commands
$ arca_cli sys.info      # Display system information
$ arca_cli sys.flush     # Flush system caches

# CLI-specific commands
$ arca_cli cli.history   # View CLI command history
$ arca_cli cli.status    # Show CLI status
$ arca_cli cli.redo      # Redo a previously executed command

# Development commands
$ arca_cli dev.info      # Show development information
$ arca_cli dev.deps      # List project dependencies
```

#### Command Sorting

By default, commands are displayed in alphabetical order to make them easier to find, especially in applications with a large number of commands. This behavior can be customized:

1. **Alphabetical Sorting (Default)**: Commands are sorted alphabetically in help output using case-insensitive comparison

   ```bash
   $ arca_cli --help
   SUBCOMMANDS:
       about               Info about the command line interface.
       cfg.get             Get a specific configuration setting
       cfg.help            Display help for cfg commands
       cfg.list            List all configuration settings
       cli.history         Show a history of recent commands.
       cli.redo            Redo a previous command from the history.
       # ... commands are listed in alphabetical order
   ```

2. **Defined Order**: For applications that need to preserve a specific ordering of commands (e.g., for workflow or logical grouping), the `sorted` configuration option can be set to `false`:

   ```elixir
   defmodule YourApp.Cli.Configurator do
     use Arca.Cli.Configurator.BaseConfigurator

     config :your_app_cli,
       commands: [
         # Commands will be displayed in this exact order
         YourApp.Cli.Commands.FirstCommand,
         YourApp.Cli.Commands.SecondCommand,
         YourApp.Cli.Commands.ThirdCommand,
       ],
       sorted: false,  # Disable alphabetical sorting
       # Other configuration...
   end
   ```

The alphabetical sorting used by Arca.Cli is case-insensitive, ensuring proper ordering of commands regardless of capitalization patterns (e.g., "cfg.list" correctly appears before "cli.history").

### Command Parameters

Commands can accept arguments, options, and flags:

```bash
# Command with a required argument
$ arca_cli settings.get id

# Command with an option
$ arca_cli example_command --count 5

# Command with a flag
$ arca_cli example_command --verbose
```

### Working with Structured Output

Arca.Cli provides a Context-based output system that cleanly separates data from presentation. Commands can return structured output using the `Arca.Cli.Ctx` module, which automatically adapts to different environments (TTY, tests, etc.).

#### Output Styles

The output system supports multiple rendering styles:

- **ANSI** (default for terminals): Colored output with symbols and formatting
- **Plain**: No ANSI codes, suitable for non-TTY environments and tests
- **JSON**: Structured JSON output
- **Dump**: Raw data inspection

Style is automatically detected based on the environment, but can be controlled:

```bash
# Force plain style
ARCA_STYLE=plain arca_cli command
NO_COLOR=1 arca_cli command

# Use JSON output
ARCA_STYLE=json arca_cli command

# Test environment uses plain automatically
MIX_ENV=test arca_cli command
```

#### Output Types

Commands using the Context system can output various types of content:

1. **Messages with Semantic Meaning**:
   - Success messages (green checkmark in ANSI mode)
   - Error messages (red X in ANSI mode)
   - Warning messages (yellow warning symbol in ANSI mode)
   - Info messages (cyan info symbol in ANSI mode)

2. **Structured Data**:
   - Tables with headers and column ordering
   - Lists with optional titles
   - Plain text content

3. **Interactive Elements** (ANSI mode only):
   - Spinners for loading operations
   - Progress indicators

#### Working with Tables

Tables automatically format data with proper alignment and borders:

```elixir
# Simple table with headers - columns appear in header order
Ctx.add_output({:table, rows, headers: ["Name", "Age", "City"]})

# Table with custom column order
Ctx.add_output({:table, rows,
  headers: ["Name", "Age", "City"],
  column_order: ["City", "Name", "Age"]  # Override header order
})

# Table with first row as headers
Ctx.add_output({:table, [["Name", "Age"] | data_rows], has_headers: true})
```

By default, when you provide headers, columns appear in the order you specify. You can override this with an explicit `column_order` option if needed.

### Customizing Output Formatting

If you are developing an application that integrates with Arca.Cli, you can customize how output is formatted using the callback system:

1. Check if the Callbacks module is available
2. Register a function for the `:format_output` or `:format_command_result` event
3. Implement your custom formatting logic

This allows you to maintain separation of concerns without creating circular dependencies between your application and Arca.Cli.

### Working with Configuration Changes

The updated Arca.Cli includes integration with Arca.Config's callback system for configuration changes. Here's how to use it:

```elixir
# Check if callback functionality is available
if Code.ensure_loaded?(Arca.Config) && function_exported?(Arca.Config, :register_change_callback, 2) do
  # Register a callback for all configuration changes
  {:ok, :registered} = Arca.Config.register_change_callback(:my_component, fn config ->
    # Handle configuration changes
    IO.puts("Configuration was updated: #{inspect(config)}")
  end)
end
```

This is particularly useful for applications that need to react to configuration changes at runtime without polling or manual reload commands.

### Testing CLI Commands

Arca.Cli includes a declarative testing framework for CLI commands that makes it easy to create integration tests using file-based fixtures.

#### Quick Start

Create a test file that uses the fixtures framework:

```elixir
defmodule MyApp.CliFixturesTest do
  use ExUnit.Case, async: false
  use Arca.Cli.Testing.CliFixturesTest

  # Tests are automatically discovered from test/cli/fixtures/
end
```

#### Basic Fixture Structure

Create fixtures under `test/cli/fixtures/`:

```
test/cli/fixtures/
  my.command/
    001/
      cmd.cli        # The command to test
      expected.out   # Expected output
```

#### Advanced Setup with Elixir Scripts

For complex test data setup, use `setup.exs` to create data programmatically:

```elixir
# test/cli/fixtures/auth.login/001/setup.exs
{:ok, user} = create_test_user("test@example.com")
{:ok, api_key} = generate_api_key(user.id)

# Return bindings for use in commands and assertions
%{
  user_id: user.id,
  api_key: api_key.plaintext
}
```

```bash
# test/cli/fixtures/auth.login/001/cmd.cli
auth.login --api-key "{{api_key}}"
```

```
# test/cli/fixtures/auth.login/001/expected.out
Authenticated successfully
User ID: {{user_id}}
```

```elixir
# test/cli/fixtures/auth.login/001/teardown.exs
# Clean up test data
if user_id = bindings[:user_id] do
  delete_user(user_id)
end
```

**Benefits of `.exs` files:**

- Fast database access (10-100x faster than CLI)
- Return computed values for assertions
- Full access to application modules
- Standard Elixir debugging tools

For complete documentation, see the [CLI Fixtures Testing](#cli-fixtures-testing) section in the Reference Guide.

## Troubleshooting

### Error Handling and Debug Mode

Arca CLI includes an enhanced error handling system with an optional debug mode for detailed error information.

#### Basic Error Messages

By default, the CLI displays concise error messages that include the error type and a descriptive message:

```
Error (invalid_argument): Invalid value provided for parameter 'count', expected an integer
```

This format makes it clear what went wrong without overwhelming you with technical details.

#### Simplified Error Handling for Developers

For developers implementing commands or integrating with Arca CLI, the error handling system provides macros that simplify creating and formatting errors:

```elixir
defmodule YourApp.Cli.Commands.ExampleCommand do
  use Arca.Cli.Command.BaseCommand
  use Arca.Cli.ErrorHandler  # Import error handling macros

  # Command implementation...

  defp validate_limit(ctx, limit) when not is_integer(limit) or limit <= 0 do
    # Using the shorthand macro (err_cfloc) for cleaner code
    # This automatically captures the current module and function name
    # and formats the error in a consistent way
    ctx
    |> Ctx.add_error(:validation, err_cfloc(
         :validation_error,
         "Limit must be a positive integer"
       ))
    |> Ctx.complete()
  end

  defp validate_and_store_error(ctx, input) do
    # For cases where you need the error object without formatting
    error = err_cloc(:invalid_input, "Invalid input format")

    # Store the error for later use
    ctx
    |> Ctx.store_error(error)
    |> Ctx.complete()
  end
end
```

This approach reduces boilerplate code and ensures consistent error handling across your application.

#### Using Debug Mode

For more complex issues, you can enable debug mode to see detailed error information:

1. **Check debug mode status**:

   ```bash
   $ arca_cli cli.debug
   Debug mode is currently OFF
   ```

2. **Enable debug mode**:

   ```bash
   $ arca_cli cli.debug on
   Debug mode is now ON
   ```

3. **Run commands with enhanced error details**:
   When debug mode is enabled, errors include additional information such as stack traces, error locations, and timestamps:

   ```
   Error (command_failed): Error executing command example
   Debug Information:
     Time: 2025-04-17 15:30:45.123Z
     Location: Arca.Cli.Commands.ExampleCommand.handle/3
     Original error: %RuntimeError{message: "Example error message"}
     Stack trace:
       Elixir.Arca.Cli.execute_command/5 (lib/arca_cli.ex:672)
       Elixir.Arca.Cli.handle_subcommand/4 (lib/arca_cli.ex:614)
       Elixir.Arca.Cli.main/1 (lib/arca_cli.ex:233)
   ```

4. **Disable debug mode when done**:

   ```bash
   $ arca_cli cli.debug off
   Debug mode is now OFF
   ```

The debug mode setting persists between CLI sessions, so you only need to enable it once while troubleshooting.

#### Error Types

Common error types you might encounter:

| Error Type          | Description                | Typical Solution                            |
| ------------------- | -------------------------- | ------------------------------------------- |
| `command_not_found` | Command doesn't exist      | Check command name and registration         |
| `invalid_argument`  | Invalid parameter provided | Check parameter format and constraints      |
| `command_failed`    | Command execution failed   | See error message for specific issue        |
| `config_error`      | Configuration error        | Verify configuration file format and values |
| `file_not_found`    | A required file is missing | Check file paths and permissions            |
| `validation_error`  | Command validation failed  | Ensure all required parameters are provided |

### Common Issues

1. **Command Not Found**:
   - Ensure the command is correctly registered in your configurator
   - Check for typos in the command name

2. **Configuration Issues**:
   - Verify that the configuration file exists (by default at `.app_name/config.json`, e.g. `.arca_cli/config.json`)
   - Check that the configuration file contains valid JSON
   - If you're using custom paths, verify the environment variables are set correctly
   - Confirm the Arca.Config registry is running properly with `Arca.Config.Server.ping()`

3. **REPL Not Responding to Tab Completion**:
   - Some terminal emulators may require special configuration for tab completion

### Environment Variables

| Variable             | Description                  | Default                       |
| -------------------- | ---------------------------- | ----------------------------- |
| APP_NAME_CONFIG_PATH | Configuration directory path | .app_name/ (e.g., .arca_cli/) |
| APP_NAME_CONFIG_FILE | Configuration filename       | config.json                   |

Note that if these environment variables are not set, Arca.Config will automatically use the application name to determine the configuration file name.

### Standard Commands

| Command             | Description                 | Arguments/Options       |
| ------------------- | --------------------------- | ----------------------- |
| about               | Show CLI information        | None                    |
| history             | Display command history     | None                    |
| redo \<index\>      | Redo a command from history | index: Command index    |
| repl                | Enter interactive mode      | None                    |
| settings.all        | Show all settings           | None                    |
| settings.get \<id\> | Get specific setting        | id: Setting name        |
| status              | Display CLI status          | None                    |
| sys.info            | Show system information     | None                    |
| sys.flush           | Flush system caches         | None                    |
| sys.cmd \<command\> | Execute system command      | command: Command to run |
