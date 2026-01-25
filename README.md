# Arca CLI

Arca CLI is a flexible command-line interface utility for Elixir projects.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `arca_cli` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:arca_cli, "~> 0.4.2"}
  ]
end
```

## Features

### Command-Line Interface

Arca CLI provides a robust command-line interface with:

- Standard commands (`about`, `status`, etc.)
- Hierarchical commands using dot notation (`sys.info`, `dev.deps`)
- Tab completion in REPL mode
- Command history and redo capabilities
- Automatic configuration management

### Configuration Management

Arca CLI uses automatic configuration detection based on the application name:

- Default configuration directory: `~/.arca/`
- Default configuration file: `arca_cli.json` (derived from application name)
- Override with environment variables:
  - `ARCA_CONFIG_PATH`: Custom configuration directory
  - `ARCA_CONFIG_FILE`: Custom configuration filename

### Dot Notation Commands

Arca CLI supports hierarchical command organization using dot notation:

```bash
# System-related commands
$ arca_cli sys.info
$ arca_cli sys.flush

# Development-related commands
$ arca_cli dev.info
$ arca_cli dev.deps

# Configuration commands
$ arca_cli config.list
$ arca_cli config.get
```

This allows for logical grouping of related commands, making the CLI more intuitive and organized.

### REPL Mode

The REPL (Read-Eval-Print Loop) mode provides an interactive shell with:

```bash
$ arca_cli repl
> help           # Display available commands
> sys.info       # Run a namespaced command
> history        # View command history
> quit           # Exit REPL mode
```

Features:

- Tab completion for commands (including dot notation)
- Command history navigation
- Easy access to grouped commands
- Customizable prompt text (static or dynamic)

### Customizing the REPL Prompt

Arca CLI supports customizable prompt text that appears before the prompt symbol in the REPL. This allows you to display contextual information such as environment, user state, or any other relevant data.

#### Configuration Options

1. **No Configuration (default)** - Uses the standard prompt format:

```elixir
# Default behavior - no prompt_text configured
config :arca_cli,
  prompt_symbol: "🔥"
# Results in: 🔥 0 >
```

2. **Static Text** - Prepends a fixed string to the prompt:

```elixir
config :arca_cli,
  prompt_symbol: "🔥",
  prompt_text: "myapp"
# Results in: myapp 🔥 0 >
```

3. **Dynamic Function** - Delegates prompt generation to a custom function:

```elixir
config :arca_cli,
  prompt_symbol: "🔥",
  prompt_text: &MyApp.Prompt.generate/1
```

#### Dynamic Prompt Function

When using a function for `prompt_text`, it receives a context map with:

- `config_domain` - The configured domain (from `:arca_config`)
- `history_count` - Current history index
- `history_cmds` - List of all history commands
- `prompt_symbol` - The configured prompt symbol

The function is responsible for generating the entire prompt string:

```elixir
defmodule MyApp.Prompt do
  def generate(%{prompt_symbol: symbol, history_count: count} = context) do
    status = get_current_status()  # Your custom logic

    case status do
      %{env: "prod", user: user} ->
        "\n⚠️  PRODUCTION (#{user}) #{symbol} #{count} > "

      %{env: env, project: project} ->
        "\n#{project}:#{env} #{symbol} #{count} > "

      _ ->
        "\n#{symbol} #{count} > "
    end
  end
end
```

This allows you to create rich, context-aware prompts that help users understand their current state at a glance.

### Creating Namespaced Commands

For developers extending Arca CLI, creating namespaced commands is simple:

1. Using the standard approach:

```elixir
defmodule YourApp.Cli.Commands.DevInfoCommand do
  use Arca.Cli.Command.BaseCommand

  config :"dev.info",
    name: "dev.info",
    about: "Display development information."

  @impl true
  def handle(_args, _settings, _optimus) do
    "Development info..."
  end
end
```

2. Using the namespace helper macro:

```elixir
defmodule YourApp.Cli.Commands.Dev do
  use Arca.Cli.Commands.NamespaceCommandHelper
  
  namespace_command :info, "Display development information" do
    "Development info..."
  end
  
  namespace_command :deps, "Show dependencies" do
    "Dependencies..."
  end
end
```

## Documentation

Full documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/arca_cli>.
