---
verblock: "06 Mar 2025:v0.1: Matthew Sinclair - Initial creation"
---

# 8. Appendices

## 8.1 Glossary

| Term         | Definition                                                                                                          |
| ------------ | ------------------------------------------------------------------------------------------------------------------- |
| CLI          | Command Line Interface, a text-based interface for interacting with software                                        |
| REPL         | Read-Eval-Print Loop, an interactive command environment that reads user input, evaluates it, and prints the result |
| Dot Notation | A convention for organizing commands hierarchically using dots as separators (e.g., `sys.info`)                     |
| Configurator | A module that defines CLI configuration, including command registration                                             |
| Command      | A self-contained unit of functionality that can be executed from the CLI                                            |
| GenServer    | An Erlang/Elixir behavior for implementing server processes with standardized interfaces                            |
| Behaviour    | An Elixir contract that defines a set of functions that a module must implement                                     |
| DSL          | Domain-Specific Language, a specialized syntax designed for a specific application domain                           |
| Escript      | A standalone executable package for Elixir applications                                                             |
| Mix          | The build tool for Elixir projects                                                                                  |

## 8.2 Command Reference

### 8.2.1 Standard Commands

| Command             | Description                       | Usage                                        |
| ------------------- | --------------------------------- | -------------------------------------------- |
| `about`             | Display information about the CLI | `arca_cli about`                             |
| `history`           | Show command history              | `arca_cli history`                           |
| `redo <index>`      | Re-execute a command from history | `arca_cli redo 3`                            |
| `repl`              | Enter interactive REPL mode       | `arca_cli repl`                              |
| `settings.all`      | List all configuration settings   | `arca_cli settings.all`                      |
| `settings.get <id>` | Get a specific setting            | `arca_cli settings.get cli.history.max_size` |
| `status`            | Display CLI status                | `arca_cli status`                            |
| `sys.info`          | Show system information           | `arca_cli sys.info`                          |
| `sys.flush`         | Flush system caches               | `arca_cli sys.flush`                         |
| `sys.cmd <command>` | Execute a system command          | `arca_cli sys.cmd "ls -la"`                  |

### 8.2.2 CLI Flags

| Flag              | Description                   | Example                                        |
| ----------------- | ----------------------------- | ---------------------------------------------- |
| `--help`, `-h`    | Display help information      | `arca_cli --help` or `arca_cli command --help` |
| `--version`, `-v` | Display version information   | `arca_cli --version`                           |
| `--quiet`, `-q`   | Suppress non-essential output | `arca_cli --quiet command`                     |

## 8.3 Configuration Reference

### 8.3.1 Environment Variables

| Variable           | Purpose                         | Default         | Example                                 |
| ------------------ | ------------------------------- | --------------- | --------------------------------------- |
| `ARCA_CONFIG_PATH` | Path to configuration directory | `~/.arca/`      | `ARCA_CONFIG_PATH="$HOME/.config/arca"` |
| `ARCA_CONFIG_FILE` | Configuration filename          | `arca_cli.json` | `ARCA_CONFIG_FILE="config.json"`        |

### 8.3.2 Configuration File Structure

```json
{
  "id": "arca_cli",
  "version": "0.3.0",
  "settings": {
    "history": {
      "max_size": 100,
      "persistence": true,
      "file_path": "~/.arca/history.dat"
    },
    "repl": {
      "prompt": "> ",
      "show_suggestions": true,
      "max_suggestions": 5
    },
    "general": {
      "color_output": true,
      "verbose_errors": true
    }
  }
}
```

## 8.4 API Examples

### 8.4.1 Defining a Command

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
    ],
    options: [
      language: [
        value_name: "LANGUAGE",
        short: "-l",
        long: "--language",
        help: "Language for greeting",
        parser: :string,
        default: "english"
      ]
    ],
    flags: [
      formal: [
        short: "-f",
        long: "--formal",
        help: "Use formal greeting"
      ]
    ]

  @impl true
  def handle(args, _settings, _optimus) do
    name = args.args.name
    language = args.options.language
    formal = args.flags.formal

    greeting = case language do
      "english" -> if formal, do: "Good day", else: "Hello"
      "spanish" -> if formal, do: "Buenos días", else: "Hola"
      _ -> "Hello"
    end

    "#{greeting}, #{name}!"
  end
end
```

### 8.4.2 Creating a Configurator

```elixir
defmodule YourApp.Cli.Configurator do
  use Arca.Cli.Configurator.BaseConfigurator

  config :your_app_cli,
    commands: [
      YourApp.Cli.Commands.GreetCommand,
      YourApp.Cli.Commands.StatusCommand,
      YourApp.Cli.Commands.UserCommand,
    ],
    author: "Your Name",
    about: "Your CLI application",
    description: "A CLI tool for your application",
    version: "1.0.0"
end
```

### 8.4.3 Integrating with Your Application

```elixir
# In config/config.exs
config :arca_cli, :configurators, [
  YourApp.Cli.Configurator,
  Arca.Cli.Configurator.DftConfigurator
]

# In mix.exs
def application do
  [
    # ...
    applications: [:arca_cli],
    # ...
  ]
end

# Create a Mix task for CLI access
defmodule Mix.Tasks.YourApp.Cli do
  use Mix.Task

  @shortdoc "Run the YourApp CLI"

  def run(args) do
    Application.ensure_all_started(:your_app)
    Arca.Cli.main(args)
  end
end
```

## 8.5 REPL Script Examples

### 8.5.1 Basic REPL Script

```bash
#!/bin/sh
# Basic REPL script without external dependencies

SCRIPT_DIR=$(dirname "$0")
exec $SCRIPT_DIR/cli repl "$@"
```

### 8.5.2 Enhanced REPL Script with rlwrap

```bash
#!/bin/sh
# Enhanced REPL script with rlwrap for improved line editing

SCRIPT_DIR=$(dirname "$0")
COMPLETIONS_FILE="$SCRIPT_DIR/completions/completions.txt"
HISTORY_FILE="$HOME/.arca/history"

# Check if rlwrap is available
if command -v rlwrap >/dev/null 2>&1; then
  # Generate completions file if it doesn't exist
  if [ ! -f "$COMPLETIONS_FILE" ]; then
    mkdir -p "$(dirname "$COMPLETIONS_FILE")"
    $SCRIPT_DIR/update_completions
  fi

  # Launch REPL with rlwrap for enhanced features
  exec rlwrap -f "$COMPLETIONS_FILE" \
              -H "$HISTORY_FILE" \
              -C "arca_cli" \
              -m \
              "$SCRIPT_DIR/cli" repl "$@"
else
  # Fall back to basic REPL
  echo "Note: Install rlwrap for enhanced command editing and completion features."
  exec "$SCRIPT_DIR/cli" repl "$@"
fi
```

## 8.6 Related Technologies

### 8.6.1 Alternative Elixir CLI Frameworks

| Framework    | Description                                     | Comparison to Arca.Cli                                                |
| ------------ | ----------------------------------------------- | --------------------------------------------------------------------- |
| OptionParser | Elixir's built-in command-line parser           | Simpler but less feature-rich, lacks REPL and history                 |
| Optimus      | Command-line parsing library                    | Used internally by Arca.Cli, focuses only on parsing                  |
| Bakeware     | Tool for creating standalone Elixir executables | Complementary; can be used with Arca.Cli for distribution             |
| Owl          | Terminal user interface toolkit                 | Complementary; can be used with Arca.Cli for rich terminal interfaces |

### 8.6.2 Similar Frameworks in Other Languages

| Framework | Language | Description                                          |
| --------- | -------- | ---------------------------------------------------- |
| Commander | Node.js  | Feature-rich command-line framework with subcommands |
| Click     | Python   | Composable command-line interface toolkit            |
| Cobra     | Go       | Library for creating powerful CLI applications       |
| Thor      | Ruby     | Toolkit for building command-line interfaces         |

## 8.7 Version History

| Version | Release Date | Key Features                                     |
| ------- | ------------ | ------------------------------------------------ |
| 0.1.0   | 2024-05-02   | Initial release with basic command functionality |
| 0.1.5   | 2024-05-17   | Added REPL mode and command history              |
| 0.2.0   | 2024-05-29   | Introduced Configurator system                   |
| 0.2.5   | 2024-06-14   | Added subcommand support                         |
| 0.3.0   | 2025-02-26   | Added hierarchical commands with dot notation    |
