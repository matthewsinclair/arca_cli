---
verblock: "06 Mar 2025:v0.1: Matthew Sinclair - Initial creation"
---

# 3. Architecture

## 3.1 Architectural Overview

Arca.Cli follows a modular architecture with clear separation of concerns between components. The system is designed around these core principles:

- Command-based interaction model
- Component-based architecture with well-defined interfaces
- Dependency injection for flexibility and testability
- Behaviour-driven design for extensibility

### 3.1.1 High-Level System Architecture

![Arca.Cli Architecture](../diagrams/architecture.png)

The system architecture consists of the following major components:

1. **CLI Core**: The central coordinator that processes commands and manages system flow
2. **Commands**: Self-contained modules that implement specific functionality
3. **Configurators**: Components that define and manage CLI configuration
4. **REPL**: Interactive command execution environment
5. **History**: Command history tracking and persistence
6. **Utilities**: Common functionality used across the system

## 3.2 Component Architecture

### 3.2.1 CLI Core

The CLI Core is responsible for:

- Parsing command-line arguments
- Dispatching commands to the appropriate handlers
- Managing application lifecycle
- Coordinating between system components

Key modules:

- `Arca.Cli`: Main entry point and coordination
- `Arca.Cli.Supervisor.HistorySupervisor`: Supervision tree for stateful components

### 3.2.2 Commands

Commands are self-contained modules that implement specific functionality. They follow a consistent interface defined by the `CommandBehaviour`.

Key modules:

- `Arca.Cli.Command.CommandBehaviour`: Protocol for command implementation
- `Arca.Cli.Command.BaseCommand`: Base implementation for standard commands
- `Arca.Cli.Command.BaseSubCommand`: Base implementation for subcommands
- Various command implementations in `Arca.Cli.Commands.*`

### 3.2.3 Configurators

Configurators are responsible for defining CLI configuration, including command registration and system settings.

Key modules:

- `Arca.Cli.Configurator.ConfiguratorBehaviour`: Protocol for configurator implementation
- `Arca.Cli.Configurator.BaseConfigurator`: Base implementation for configurators
- `Arca.Cli.Configurator.DftConfigurator`: Default configurator with standard commands
- `Arca.Cli.Configurator.Coordinator`: Coordinates between multiple configurators

### 3.2.4 REPL

The REPL system provides an interactive command execution environment with features like command history and tab completion.

Key modules:

- `Arca.Cli.Repl.Repl`: Main REPL implementation
- Integration with `rlwrap` for enhanced terminal capabilities

### 3.2.5 History

The History component tracks and persists command execution history.

Key modules:

- `Arca.Cli.History.History`: GenServer implementation for history tracking
- Persistence mechanisms for history storage

### 3.2.6 Utilities

Utilities provide common functionality used across the system.

Key modules:

- `Arca.Cli.Utils.Utils`: General utility functions
- String manipulation and type conversion helpers

## 3.3 Data Flow

### 3.3.1 Command Execution Flow

1. User inputs a command (CLI args or REPL input)
2. Input is parsed and validated
3. Command is resolved to a specific handler
4. Command is added to history
5. Command handler is invoked with parsed arguments
6. Result is returned to the user

### 3.3.2 Configuration Flow

1. System loads application configuration from Mix config
2. Environment variables are applied as overrides
3. Configurators are initialized in priority order
4. Commands are registered from all configurators
5. User settings are loaded from persistent storage
6. Settings are made available to all components

## 3.4 External Interfaces

### 3.4.1 Command Line Interface

The system provides a command-line interface through:

- Direct invocation via `arca_cli [command] [args]`
- Interactive mode via `arca_cli repl`

### 3.4.2 Configuration Files

The system uses JSON configuration files stored in:

- Default location: `~/.arca/arca_cli.json`
- Custom location specified by environment variables

### 3.4.3 Application Integration

Applications can integrate with Arca.Cli by:

- Adding it as a dependency
- Creating custom configurators
- Defining application-specific commands

## 3.5 Design Decisions and Rationale

### 3.5.1 Behaviour-Driven Design

Arca.Cli uses Elixir behaviours extensively to define clear interfaces between components. This approach:

- Enables loose coupling between components
- Facilitates extension through custom implementations
- Simplifies testing through interface contracts

### 3.5.2 Command Registration via Configurators

The system uses Configurators to register commands rather than direct registration. This approach:

- Allows grouping related commands
- Enables prioritized command resolution
- Supports multiple command sources (core, application, plugins)

### 3.5.3 History as a Supervised GenServer

Command history is implemented as a supervised GenServer rather than simple file persistence. This approach:

- Ensures fault tolerance through the supervision tree
- Optimizes performance by caching history in memory
- Facilitates synchronized access from multiple components

### 3.5.4 Hierarchical Command Organization

Commands are organized hierarchically using dot notation. This approach:

- Creates a more intuitive command structure
- Avoids command name collisions
- Improves discoverability through logical grouping
