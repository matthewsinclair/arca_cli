---
verblock: "20 Mar 2025:v0.1: Matthew Sinclair - Updated via STP upgrade"
stp_version: 1.0.0
status: Completed
created: 20250319
completed: 20250922
---

# ST0003: REPL Output Callback System

## Objective

Implement a callback system in Arca.Cli that allows external applications like Multiplyer to customize the output formatting in the REPL without creating circular dependencies.

## Context

Arca.Cli includes a REPL (Read-Eval-Print Loop) module that provides an interactive command-line interface. Currently, the output formatting capabilities are limited and there is no way for external applications to customize this formatting without direct dependencies. This creates an issue for applications like Multiplyer that need to modify how REPL output is presented to users.

We need to create a generic callback system within Arca.Cli that enables external applications to register formatters and customize output without introducing circular dependencies.

## Approach

1. Create a new callback registry module (`Arca.Cli.Callbacks`) that allows registration of callback functions for specific events
2. Modify the REPL's print function to use the callback system for output formatting
3. Implement a clean design that falls back to default behavior when no callbacks are registered
4. Document the callback system to facilitate integration by external applications

## Tasks

- [x] Create the `Arca.Cli.Callbacks` module with registration and execution functionality
- [x] Implement the `register/2` function to allow registering callbacks for specific events
- [x] Implement the `execute/2` function to run callbacks in appropriate order
- [x] Add the `has_callbacks?/1` function to check for registered callbacks
- [x] Modify the REPL's `print/1` function to use the callback system
- [x] Add fallback to original implementation when no callbacks are registered
- [x] Add comprehensive tests for the callback system
- [x] Update documentation to explain the callback system and integration patterns
- [x] Create example implementations to demonstrate proper usage

## Implementation Notes

The callback system was implemented with a chain of responsibility pattern, where:

- Multiple callbacks can be registered for a specific event
- Callbacks are executed in reverse registration order (last registered, first executed)
- Each callback can decide to continue the chain or halt with a specific result
- The system falls back to default behavior if no callbacks are registered

For the REPL output formatting, the implementation:

- Checks if any `:format_output` callbacks are registered
- If yes, executes all callbacks with the output
- If no, uses the original implementation

The callbacks module provides three main functions:

1. `register/2` - Registers a callback function for a specific event
2. `execute/2` - Executes all callbacks for an event in reverse registration order
3. `has_callbacks?/1` - Checks if any callbacks are registered for an event

The REPL's print function was modified to use a `with` pattern for cleaner control flow:

```elixir
defp print(out) do
  with true <- Code.ensure_loaded?(Callbacks),
       true <- Callbacks.has_callbacks?(:format_output) do
    out
    |> Callbacks.execute(:format_output)
    |> IO.puts()

    out
  else
    _ -> Utils.print(out)
  end
end
```

## Results

The following benefits have been achieved:

- External applications can now customize Arca.Cli's output formatting
- No circular dependencies are created between Arca.Cli and dependent applications
- Multiple applications can register callbacks for the same event
- Graceful fallback to default behavior when no callbacks are registered
- Clean and maintainable extension points for future functionality

The callback system has been fully implemented and tested, providing a flexible mechanism for output customization. This enables Multiplyer to integrate its OutputContext system with Arca.Cli's REPL while maintaining proper separation of concerns.

User documentation has been updated to reflect these changes:

1. Added callback system details to user guides
2. Added integration examples for external applications
3. Updated the reference guide with detailed callback API documentation

Remaining work includes:

1. Integrating with Multiplyer's OutputContext system
2. Potential enhancements to provide more specific formatting events for different output types

## Links

- [Callbacks Implementation](/lib/arca_cli/callbacks.ex)
- [REPL Implementation](/lib/arca_cli/repl/repl.ex)
- [Callbacks Tests](/test/arca_cli/callbacks/callbacks_test.exs)
- [Formatter Tests](/test/arca_cli/repl/repl_formatter_test.exs)
- [Example Formatter](/test/arca_cli/callbacks/example_formatter.ex)
- [Related ST0002: REPL Tab Completion Improvements](/stp/prj/st/ST0002.md)
- [Instructions on what to do](./ST0003_arca_cli_changes.md)
