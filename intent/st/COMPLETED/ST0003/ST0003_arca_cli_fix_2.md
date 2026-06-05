---
verblock: "20 Mar 2025:v0.1: Matthew Sinclair - Updated via STP upgrade"
stp_version: 1.0.0
status: Not Started
created: 20250320
completed:
---

# Arca.Cli REPL Output Fix

## Issue Description

When using Arca.Cli's REPL with custom formatters registered via `Arca.Cli.Callbacks.register(:format_output, callback)`, there is an issue where `"format_output"` text appears in the console after each command's output.

Additionally, built-in commands like `help` and `?` may not work properly when custom formatters are registered, as they may not properly handle the output formatting chain.

## Root Cause Analysis

After examining the code, the issue appears to be in the `print/1` function in `Arca.Cli.Repl` (around line 406 in `lib/arca_cli/repl/repl.ex`):

```elixir
# Current implementation
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

The REPL appears to be handling the output in a way that causes both the formatter result and possibly the callback name or some debug information to be displayed.

## Proposed Fix

Modify the `print/1` function in `Arca.Cli.Repl` to handle the output more cleanly:

```elixir
# Proposed fix
defp print(out) do
  with true <- Code.ensure_loaded?(Callbacks),
       true <- Callbacks.has_callbacks?(:format_output) do
    # Get formatted output from callbacks
    formatted = Callbacks.execute(:format_output, out)

    # Only print if it's not empty
    if formatted && formatted != "" do
      IO.puts(formatted)
    end

    out
  else
    _ -> Utils.print(out)
  end
end
```

This change:

1. Gets the formatted output from the callback chain
2. Only prints it if it's not empty (allows formatters to suppress output)
3. Maintains the same return value for proper command flow

## Benefits

- Eliminates the "format_output" text that appears after each command
- Preserves the ability for formatters to suppress output when needed
- Maintains compatibility with existing formatter callbacks
- Ensures built-in commands like `help` and `?` continue to work properly

## Testing

This change should be tested with:

- Default output (no formatters registered)
- Built-in commands like `help`, `?`, and other REPL-specific commands
- Custom formatters that use both `{:cont, value}` and `{:halt, result}` returns
- Nested command namespaces
- Custom output formatters like the one in Multiplyer
