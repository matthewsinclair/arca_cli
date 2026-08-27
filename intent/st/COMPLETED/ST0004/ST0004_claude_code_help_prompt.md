---
verblock: "20 Mar 2025:v0.1: Matthew Sinclair - Updated via STP upgrade"
stp_version: 1.0.0
status: Not Started
created: 20250320
completed:
---

# Integrating with Arca.Cli's New Help System (v0.4.0+)

I need to update my codebase to work with the latest version of Arca.Cli (v0.4.0+) which includes a new centralized help system. Please analyze my codebase and help me make the necessary changes to ensure compatibility.

## Background

Arca.Cli v0.4.0 introduced a completely redesigned help system that addresses several fundamental issues with the previous implementation:

1. **Centralized Help Logic**: All help functionality is now in the dedicated `Arca.Cli.Help` module
2. **Pre-execution Checks**: Help detection occurs before command execution rather than within commands
3. **Declarative Configuration**: Commands explicitly declare their help behavior via config
4. **Callback Integration**: Help formatting uses the standard callback system for customization
5. **Consistent Behavior**: All three help scenarios are handled consistently:
   - Command invoked without parameters (`cli cmd`)
   - Command invoked with `--help` flag (`cli cmd --help`)
   - Command invoked with help prefix (`cli help cmd`)
6. **Better REPL Integration**: Help in REPL mode works the same as in CLI mode

## Key Changes

The new help system makes these key architectural changes:

1. **Help Detection Logic**: Moved from individual commands to centralized `Arca.Cli.Help.should_show_help?/3`
2. **Declarative Configuration**: Commands indicate when help should be shown with `show_help_on_empty: true|false`
3. **Help Formatting**: Standardized through the callback system with `:format_help` event
4. **REPL/CLI Consistency**: Unified help display approach across all modes

## Required Updates

Please make the following changes to my codebase:

### 1. Command Configuration Updates

For all command modules implementing `Arca.Cli.Command.CommandBehaviour`:

```elixir
# Before: No explicit help configuration
config :command_name,
  name: "command_name",
  about: "Command description"

# After: Explicit help configuration
config :command_name,
  name: "command_name",
  about: "Command description",
  show_help_on_empty: true  # Set to true for commands requiring args
                           # Set to false for commands that work without args
```

#### Guidelines for `show_help_on_empty`:

- **Set to `true` for**:
  - Commands that require at least one argument or option
  - Commands where empty invocation doesn't make sense
  - Commands that should show help instead of executing when called without args

- **Set to `false` for**:
  - Commands that perform a useful action without any arguments
  - Status commands, version commands, or other informational commands
  - Commands where empty invocation has a sensible default behavior

### 2. Remove Custom Help Detection Logic

Remove any code that manually checks for help conditions:

```elixir
# REMOVE patterns like these from command handlers:

# Pattern 1: Empty args check
if Enum.empty?(args) do
  # show help...
end

# Pattern 2: Help flag check
if args.flags.help do
  # show help...
end

# Pattern 3: Manual help text generation
def format_help_text do
  # custom help formatting...
end
```

### 3. Help Formatting (Optional)

If you need custom help formatting, implement it using the callback system:

```elixir
# In your application startup code (e.g., Application.start/2)
if Code.ensure_loaded?(Arca.Cli.Callbacks) do
  Arca.Cli.Callbacks.register(:format_help, fn help_text ->
    # Format help_text according to your needs
    # help_text is a list of strings, one per line

    formatted_help = MyApp.Formatters.format_help(help_text)

    # Return one of:
    # {:cont, modified_text} - Continue processing with other callbacks
    # {:halt, final_text} - Stop processing and use this result
    # modified_text - Same as {:cont, modified_text}
    {:halt, formatted_help}
  end)
end
```

## Complete Example

### Original Command with Custom Help Logic:

```elixir
defmodule MyApp.Commands.QueryCommand do
  use Arca.Cli.Command.BaseCommand

  config :query,
    name: "query",
    about: "Query data from the system",
    args: [
      id: [
        value_name: "ID",
        help: "ID to query",
        required: true,
        parser: :string
      ]
    ],
    flags: [
      verbose: [
        short: "v",
        help: "Show verbose output",
        multiple: false
      ]
    ]

  @impl true
  def handle(args, settings, optimus) do
    # Custom help handling - REMOVE THIS
    cond do
      args == :help ->
        generate_help(optimus)

      is_tuple(args) && elem(args, 0) == :help ->
        generate_help(optimus)

      # Check for empty arguments - REMOVE THIS
      (is_map(args) && Enum.empty?(Map.get(args, :args, %{}))) ->
        generate_help(optimus)

      # Check for help flag - REMOVE THIS
      (is_map(args) && Map.get(args, :flags, %{}) |> Map.get(:help, false)) ->
        generate_help(optimus)

      true ->
        # Actual command logic
        execute_query(args.args.id, args.flags.verbose, settings)
    end
  end

  # Custom help generation - REMOVE THIS
  defp generate_help(optimus) do
    [
      "Query data from the system",
      "",
      "USAGE:",
      "    cli query ID [options]",
      "",
      "ARGUMENTS:",
      "    ID    ID to query",
      "",
      "OPTIONS:",
      "    -v, --verbose    Show verbose output"
    ]
  end

  defp execute_query(id, verbose, settings) do
    # Actual implementation...
  end
end
```

### Updated Command with New Help System:

```elixir
defmodule MyApp.Commands.QueryCommand do
  use Arca.Cli.Command.BaseCommand

  config :query,
    name: "query",
    about: "Query data from the system",
    # ADD THIS: Explicitly set help behavior for commands requiring args
    show_help_on_empty: true,
    args: [
      id: [
        value_name: "ID",
        help: "ID to query",
        required: true,
        parser: :string
      ]
    ],
    flags: [
      verbose: [
        short: "v",
        help: "Show verbose output",
        multiple: false
      ]
    ]

  @impl true
  def handle(args, settings, optimus) do
    # Command logic only - no help handling
    execute_query(args.args.id, args.flags.verbose, settings)
  end

  defp execute_query(id, verbose, settings) do
    # Actual implementation...
  end
end
```

### Optional: Custom Help Formatting

```elixir
# In your application.ex or other initialization code
defmodule MyApp.Application do
  use Application

  def start(_type, _args) do
    # Set up help formatting
    if Code.ensure_loaded?(Arca.Cli.Callbacks) do
      Arca.Cli.Callbacks.register(:format_help, fn help_text ->
        # Add corporate branding or special formatting
        branded_help = ["[MyApp Help System]" | help_text]

        # Format with colors or other enhancements
        formatted = Enum.map(branded_help, &MyApp.Formatters.colorize/1)

        {:halt, formatted}
      end)
    end

    # Rest of your application startup...
    children = [
      # ...
    ]

    opts = [strategy: :one_for_one, name: MyApp.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```

## Comprehensive Checklist

1. **Command Configuration**
   - [ ] Identify all commands in the codebase
   - [ ] Determine appropriate `show_help_on_empty` value for each
   - [ ] Add the configuration parameter to each command

2. **Cleanup**
   - [ ] Remove custom help detection logic from command handlers
   - [ ] Remove custom help generation methods
   - [ ] Remove help-related conditional logic in command handlers

3. **Feature Validation**
   - [ ] Test all commands with no arguments to verify help behavior
   - [ ] Test all commands with `--help` flag
   - [ ] Test all commands with `help` prefix
   - [ ] Verify REPL help works consistently with CLI help

4. **Optional Enhancements**
   - [ ] Implement custom help formatting via callback system if needed
   - [ ] Update documentation to reflect new help behavior

## Common Pitfalls

1. **Forgetting Configurator Updates**: If you have custom configurators that override command options, ensure they preserve the `show_help_on_empty` setting.

2. **Incomplete Cleanup**: Ensure all custom help handling code is removed. Look for patterns like:
   - Checking for `:help` atoms or tuples
   - Direct interaction with Optimus.Help
   - Manual generation of help text

3. **Duplicate Help Logic**: The framework now handles all help scenarios. Don't add additional help checks that could interfere.

4. **External Integration Issues**: If your application integrates with other systems via Arca.Cli, ensure those integrations are aware of the new help behavior.

## Support

For issues or questions regarding the new help system, refer to:

- The Arca.Cli documentation
- The Steel Thread 0004 documentation in the Arca.Cli repository
- Support channels for Arca.Cli
