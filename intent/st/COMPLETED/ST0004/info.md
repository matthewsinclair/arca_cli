---
verblock: "20 Mar 2025:v0.1: Matthew Sinclair - Updated via STP upgrade"
stp_version: 1.0.0
status: Completed
created: 20250320
completed: 20250319
---

# ST0004: Improved Help Subsystem for CLI

## Overview

This steel thread addresses the need for a more reliable, consistent, and simpler help system for the Arca.Cli framework. The current help implementation has several issues:

1. Inconsistent help display between CLI and REPL modes
2. Brittle help handling logic scattered across different parts of the codebase
3. Lack of a standardized approach for commands to indicate when help should be shown
4. No clear separation between help generation and output formatting

## Goals

- Create a unified help subsystem that provides consistent behavior across all usage scenarios
- Centralize help logic in a dedicated module with pre-execution hooks
- Leverage the existing callback system for help formatting and display
- Ensure backward compatibility where possible, but prioritize a clean design
- Add comprehensive tests to validate help behavior in all scenarios

## Help Scenarios

The improved system will handle these three main help scenarios consistently:

1. Command invoked without parameters (`cli cmd`)
2. Command invoked with `--help` flag (`cli cmd --help`)
3. Command invoked with help prefix (`cli help cmd`)

## Proposed Design

### 1. Centralized Help Module

Create a dedicated `Arca.Cli.Help` module that centralizes all help-related functionality:

```elixir
defmodule Arca.Cli.Help do
  def show(cmd, args, optimus) do
    # Generate and display help for a command
    help_text = generate_help(cmd, optimus)
    format_and_display(help_text)
  end

  def should_show_help?(cmd, args) do
    # Logic to determine if help should be shown based on:
    # - Command configuration (show_help_on_empty)
    # - Presence of --help flag
    # - Whether args are empty for commands that require args
  end

  defp generate_help(cmd, optimus) do
    # Generate appropriate help text
  end

  defp format_and_display(help_text) do
    # Use callback system to format and display help
    Arca.Cli.Callbacks.execute(:format_help, help_text)
  end
end
```

### 2. Pre-Execution Help Check

Add a pre-execution hook in the command dispatch flow to check if help should be shown:

```elixir
def handle_command(cmd, args, settings, optimus) do
  # Check if help should be shown before executing the command
  if Arca.Cli.Help.should_show_help?(cmd, args) do
    Arca.Cli.Help.show(cmd, args, optimus)
  else
    # Continue with normal command execution
    execute_command(cmd, args, settings, optimus)
  end
end
```

### 3. Callback Integration

Extend the existing callback system to include a new `:format_help` event:

```elixir
Arca.Cli.Callbacks.register(:format_help, fn help_text ->
  # Custom formatting logic
  {:halt, formatted_help}
end)
```

### 4. Command Configuration

Update the command behavior to include clearer help configuration:

```elixir
@type t :: [
  {:name, String.t()} |
  {:about, String.t()} |
  {:show_help_on_empty, boolean()} |
  {:help_text, String.t() | [String.t()]}
]
```

## Implementation Plan

1. Create a new `Arca.Cli.Help` module to centralize help-related functionality
2. Add pre-execution help check in the command dispatch flow
3. Update `CommandBehaviour` to include help-related types
4. Extend the callback system to support help formatting
5. Refactor existing help-handling code to use the new system
6. Add comprehensive tests for all help scenarios

## Backward Compatibility

While some breaking changes are expected, we'll strive to:

1. Support existing command configurations
2. Maintain compatibility with the `show_help_on_empty` option
3. Provide clear migration guides for any breaking changes

## Testing Strategy

We'll create comprehensive tests that cover:

1. All three help invocation methods (no params, `--help` flag, `help` prefix)
2. Both CLI and REPL modes
3. Commands that should show help on empty and those that shouldn't
4. Help formatting via the callback system
5. Edge cases like unknown commands and malformed help requests

## Risks and Mitigations

| Risk                                          | Mitigation                                                              |
| --------------------------------------------- | ----------------------------------------------------------------------- |
| Breaking changes impact existing applications | Provide clear migration guide and maintain compatibility where feasible |
| Complexity increase                           | Focus on simple design with clear separation of concerns                |
| Performance impact                            | Ensure help generation is efficient and only occurs when needed         |
| Incomplete test coverage                      | Create comprehensive test suite covering all use cases                  |

## Success Criteria

- Help behaves consistently across all invocation methods
- Pre-execution help check works reliably
- Applications can customize help formatting via callbacks
- All help scenarios are covered by tests
- Help subsystem is well-documented and easy to understand

## Deliverables

1. New `Arca.Cli.Help` module with centralized help functionality
2. Pre-execution help check in command dispatch flow
3. Extended callback system for help formatting
4. Comprehensive test suite
5. Documentation for the new help subsystem
6. Migration guide for existing applications
7. Claude Code prompt template for dependent projects that explains how to integrate with the new help subsystem

The Claude Code prompt will provide clear instructions and examples for dependent projects to adapt to the new help system, ensuring a smooth transition and consistent implementation across the ecosystem.

## Next Steps

1. Review this design with stakeholders
2. Create initial implementation focusing on core functionality
3. Develop test suite to validate behavior
4. Refine implementation based on feedback and test results
5. Document the new system for end users
