---
verblock: "17 Apr 2025:v0.6: Claude - Added error handling and debug mode documentation"
---

# Arca.Cli Deployment Guide

This deployment guide provides instructions for deploying the Arca.Cli system in various environments. It covers installation, configuration, and integration with other tools and workflows.

## Table of Contents

1. [Installation](#installation)
2. [Configuration](#configuration)
3. [Integration](#integration)
4. [Maintenance](#maintenance)
5. [Upgrading](#upgrading)
6. [Troubleshooting](#troubleshooting)

## Installation

### System Requirements

- Elixir 1.14 or later
- Erlang 25 or later
- POSIX-compatible shell environment (bash, zsh)
- Terminal with Unicode support

### Installation Methods

#### As a Project Dependency

The most common way to use Arca.Cli is as a dependency in your Elixir project:

```bash
# Create a new Elixir project (if needed)
mix new your_app

# Navigate to your project
cd your_app
```

Add Arca.Cli to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:arca_cli, "~> 0.4.0"},
    # You can specify the latest Arca.Config explicitly
    {:arca_config, "~> 0.2.0", github: "organization/arca_config"}
  ]
end
```

Install the dependency:

```bash
mix deps.get
```

#### Standalone Installation

To install Arca.Cli as a standalone executable:

```bash
# Clone the repository
git clone https://github.com/your-org/arca_cli.git

# Navigate to the directory
cd arca_cli

# Build the executable
mix escript.build

# Move the executable to a directory in your PATH
sudo mv arca_cli /usr/local/bin/
```

#### Installation Verification

Verify the installation:

```bash
# If installed as a dependency
mix arca_cli --help

# If installed as a standalone executable
arca_cli --help
```

## Configuration

### Environment Variables

Configure Arca.Cli behavior using these environment variables:

#### Configuration Variables

| Variable             | Purpose                      | Default                       |
| -------------------- | ---------------------------- | ----------------------------- |
| APP_NAME_CONFIG_PATH | Configuration directory path | .app_name/ (e.g., .arca_cli/) |
| APP_NAME_CONFIG_FILE | Configuration filename       | config.json                   |

Note: The actual environment variable names are derived from the application name (in UPPERCASE). For example, for the `arca_cli` application, the environment variables would be `ARCA_CLI_CONFIG_PATH` and `ARCA_CLI_CONFIG_FILE`.

#### Output Style Variables

| Variable   | Purpose                     | Values                            | Default |
| ---------- | --------------------------- | --------------------------------- | ------- |
| ARCA_STYLE | Force specific output style | ansi, plain, json, dump           | auto    |
| NO_COLOR   | Disable colored output      | 1 (to disable), unset (to enable) | unset   |
| MIX_ENV    | Elixir environment          | test, dev, prod                   | dev     |

**Output Style Behavior:**

- `ARCA_STYLE=ansi`: Force colored ANSI output with symbols and formatting
- `ARCA_STYLE=plain`: Force plain text output without ANSI codes
- `ARCA_STYLE=json`: Output structured JSON for programmatic consumption
- `ARCA_STYLE=dump`: Output raw data structures for debugging
- `NO_COLOR=1`: Disable colors (equivalent to `ARCA_STYLE=plain`)
- `MIX_ENV=test`: Automatically uses plain style for test output

**Style Detection Priority:**

1. Test environment (`MIX_ENV=test`) → Plain style
2. `NO_COLOR=1` → Plain style
3. `ARCA_STYLE` value → Specified style
4. Non-TTY environment → Plain style
5. Interactive TTY → ANSI style (default)

**Usage Examples:**

```bash
# Force plain output for scripting
ARCA_STYLE=plain arca_cli command > output.txt

# Disable colors for CI/CD pipelines
NO_COLOR=1 arca_cli command

# Get JSON for parsing
ARCA_STYLE=json arca_cli command | jq '.output'

# Debug with raw data structures
ARCA_STYLE=dump arca_cli command
```

Example configuration in `.bashrc` or `.zshrc` for an application named `arca_cli`:

```bash
export ARCA_CLI_CONFIG_PATH="$HOME/.config/arca_cli/"
export ARCA_CLI_CONFIG_FILE="custom_config.json"
```

### Application Configuration

Configure Arca.Cli in your Elixir application:

```elixir
# In config/config.exs
config :arca_cli,
  # Register configurators
  configurators: [
    YourApp.Cli.Configurator,
    Arca.Cli.Configurator.DftConfigurator
  ],
  # Enable or disable debug mode (for detailed error information)
  debug_mode: false  # Set to true for development environments

# Configure Arca.Config with registry and file watching options
config :arca_config,
  # Optional, defaults to the current application name
  parent_app: :your_app,
  # Optional, defaults to ".{app_name}/" (e.g., ".your_app/")
  default_config_path: "/custom/path",
  # Optional, defaults to "config.json"
  default_config_file: "custom.json",
  # Enable file watching
  watch_file: true,
  # Check for file changes every 1000ms
  watch_interval: 1000
```

### Project Configuration

Create a custom configurator for your project:

```elixir
defmodule YourApp.Cli.Configurator do
  use Arca.Cli.Configurator.BaseConfigurator

  config :your_app_cli,
    commands: [
      YourApp.Cli.Commands.CustomCommand,
    ],
    author: "Your Name",
    about: "Your CLI application",
    description: "A CLI tool for your application",
    version: "1.0.0"
end
```

## Integration

### Version Control Integration

#### Recommended .gitignore

```
# Arca.Cli files
.arca/
*.json
```

### Mix Tasks Integration

Create custom Mix tasks that use Arca.Cli:

```elixir
defmodule Mix.Tasks.YourApp.Cli do
  use Mix.Task

  @shortdoc "Run the YourApp CLI"

  def run(args) do
    Application.ensure_all_started(:your_app)
    Arca.Cli.main(args)
  end
end
```

### Output Formatting Integration

To customize Arca.Cli's output formatting from your application:

```elixir
defmodule YourApp.Formatter do
  @doc """
  Initializes the integration with Arca.Cli
  """
  def setup do
    if Code.ensure_loaded?(Arca.Cli.Callbacks) do
      Arca.Cli.Callbacks.register(:format_output, &format_output/1)
    end
  end

  @doc """
  Custom formatter for Arca.Cli output
  """
  def format_output(output) do
    # Apply your formatting logic here
    formatted = YourApp.FormatContext.process(output)

    # Return formatted output and stop the callback chain
    {:halt, formatted}
  end
end
```

Call the setup function when your application starts:

```elixir
defmodule YourApp.Application do
  use Application

  def start(_type, _args) do
    # Setup the Arca.Cli integration if available
    YourApp.Formatter.setup()

    # ... rest of your application start function
  end
end
```

### Arca.Config Registry Integration

The updated Arca.Cli uses Arca.Config's Registry integration for more robust configuration management. To properly integrate this in your application:

```elixir
defmodule YourApp.Application do
  use Application

  def start(_type, _args) do
    children = [
      # Other children...

      # Add Arca.Config.Supervisor to your supervision tree
      {Arca.Config.Supervisor, []}
    ]

    # Start the supervision tree
    opts = [strategy: :one_for_one, name: YourApp.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```

You can also set up configuration change listeners:

```elixir
defmodule YourApp.ConfigChangeHandler do
  @doc """
  Initialize configuration change handlers
  """
  def setup do
    if Code.ensure_loaded?(Arca.Config) && function_exported?(Arca.Config, :register_change_callback, 2) do
      # Register for all configuration changes
      Arca.Config.register_change_callback(:your_component, &handle_config_changes/1)

      # Subscribe to specific keys
      Arca.Config.subscribe("feature.enabled")
    end
  end

  @doc """
  Handler for all configuration changes
  """
  def handle_config_changes(config) do
    # Process configuration changes
    IO.puts("Configuration updated: #{inspect(config)}")
  end

  @doc """
  Handler for process that wants to receive messages about specific keys
  This would be implemented in a GenServer's handle_info callback
  """
  def handle_info({:config_updated, "feature.enabled", value}, state) do
    # React to the specific configuration change
    {:noreply, %{state | feature_enabled: value}}
  end
end
```

### CI/CD Integration

For CI/CD environments, ensure the configuration path is set correctly:

```yaml
# GitHub Actions example for an app named arca_cli
jobs:
  test:
    runs-on: ubuntu-latest
    env:
      ARCA_CLI_CONFIG_PATH: "/tmp/arca_cli"
    steps:
      - uses: actions/checkout@v3
      - uses: erlef/setup-beam@v1
        with:
          otp-version: 25
          elixir-version: 1.14
      - run: mix deps.get
      - run: mix test
```

### IDE Integration

#### Visual Studio Code

Add launch configuration for debugging:

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "type": "mix_task",
      "name": "Run CLI",
      "request": "launch",
      "task": "arca_cli",
      "taskArgs": ["about"],
      "env": {
        "ARCA_CLI_CONFIG_PATH": "${workspaceFolder}/.arca_cli"
      }
    }
  ]
}
```

## Maintenance

### Regular Maintenance Tasks

- Update dependencies periodically with `mix deps.update arca_cli`
- Clean up command history if it grows too large
- Review and update custom commands as needed

### Backup Practices

- Include configuration files in backups
- Store custom command implementations in version control
- Document command workflows for knowledge sharing

## Upgrading

### Upgrading Arca.Cli

To upgrade Arca.Cli to the latest version:

```elixir
# In mix.exs
def deps do
  [
    {:arca_cli, "~> 0.4.0"} # Update to the desired version
  ]
end
```

Then update dependencies:

```bash
mix deps.update arca_cli
```

### Upgrading Arca.Config

When upgrading to the latest version of Arca.Config with Registry integration:

1. Update the dependency in mix.exs:

   ```elixir
   def deps do
     [
       # Update to use the GitHub repository for the latest version
       {:arca_config, "~> 0.2.0", github: "organization/arca_config"}
     ]
   end
   ```

2. Ensure your application properly starts the Arca.Config supervisor:

   ```elixir
   # In your application.ex
   children = [
     # Other children...
     {Arca.Config.Supervisor, []}
   ]
   ```

3. Update any code that directly interacts with Arca.Config to use the public API:

   ```elixir
   # Use public API functions
   Arca.Config.get("key.path")
   Arca.Config.put("key.path", value)
   Arca.Config.Server.reload()
   ```

4. Take advantage of the new features:

   ```elixir
   # Register for configuration changes
   Arca.Config.register_change_callback(:component_id, fn config ->
     # Handle changes
   end)

   # Subscribe to specific key changes
   Arca.Config.subscribe("specific.key.path")
   ```

5. Note that the configuration file paths are now automatically derived:
   - By default, Arca.Config will use a configuration directory named after your application
   - For example, if your application is named `:my_app`, the config file will be `.my_app/config.json`
   - This can be overridden with application-specific environment variables (e.g., `MY_APP_CONFIG_PATH` and `MY_APP_CONFIG_FILE`) or explicit configuration

### Migrating Between Major Versions

When upgrading between major versions:

1. Review the changelog for breaking changes
2. Update any custom commands to match new interfaces
3. Migrate configuration to the new format if necessary
4. Run tests to verify compatibility
5. Update documentation to reflect changes

## Troubleshooting

### Common Issues

#### Command Not Found

**Problem**: The CLI reports that a command cannot be found.

**Solution**:

- Verify the command is registered in your configurator
- Check for typos in the command name
- Ensure your configurator is registered in the application configuration

#### Configuration File Issues

**Problem**: The CLI cannot find or load the configuration file.

**Solution**:

- Check that the configuration directory exists (`.app_name/` in the current directory by default, e.g., `.arca_cli/`)
- Verify the configuration file exists and is named `config.json`
- Set the application-specific environment variables (e.g., `ARCA_CLI_CONFIG_PATH` and `ARCA_CLI_CONFIG_FILE` for the arca_cli app) if using custom locations

#### Registry-Related Errors

**Problem**: You see errors related to the Arca.Config Registry.

**Solution**:

- Ensure the Arca.Config.Supervisor is started correctly
- Check that you don't have multiple instances of Arca.Config running
- Verify registry configuration in config.exs

#### REPL Tab Completion Not Working

**Problem**: Tab completion doesn't work in REPL mode.

**Solution**:

- Install `rlwrap` for improved REPL experience (`brew install rlwrap` on macOS)
- Some terminals may require additional configuration for proper tab completion

### Debug Mode for Troubleshooting

Arca CLI includes an enhanced error handling system with debug mode that provides detailed error information:

```bash
# Check the current debug mode status
arca_cli cli.debug
Debug mode is currently OFF

# Enable debug mode for detailed error information
arca_cli cli.debug on
Debug mode is now ON

# When debug mode is enabled, errors show more detailed information:
arca_cli some_command_with_error
Error (command_failed): Failed to execute command
Debug Information:
  Time: 2025-04-17 15:30:45.123Z
  Location: Arca.Cli.Commands.SomeCommand.handle/3
  Original error: %RuntimeError{message: "Something went wrong"}
  Stack trace:
    Elixir.Arca.Cli.Commands.SomeCommand.handle/3 (lib/arca_cli/commands/some_command.ex:25)
    Elixir.Arca.Cli.execute_command/5 (lib/arca_cli.ex:672)
    Elixir.Arca.Cli.handle_subcommand/4 (lib/arca_cli.ex:614)
    Elixir.Arca.Cli.main/1 (lib/arca_cli.ex:233)

# Disable debug mode when finished troubleshooting
arca_cli cli.debug off
Debug mode is now OFF
```

The debug mode setting persists between CLI sessions, so you only need to enable it once while troubleshooting.

### Diagnostic Commands

Use these commands to diagnose issues:

```bash
# Show CLI status and configuration
arca_cli status

# Show system information
arca_cli sys.info

# List all settings
arca_cli settings.all

# Toggle debug mode for detailed error information
arca_cli cli.debug on
```

### Getting Help

For additional help:

- Check the [Arca.Cli Documentation](https://hexdocs.pm/arca_cli)
- Review the [GitHub repository](https://github.com/your-org/arca_cli)
- Join the [Elixir Forum](https://elixirforum.com) to ask questions
