# Command Naming Convention Validation Test

## Background

This document provides manual test instructions for verifying the command naming convention validation fix.

## The Issue

A subtle bug existed where command name mismatches between:

- The command atom name used in the `config :name, ...` call
- The module name's suffix (without "Command")

This would cause silent failures at runtime during command dispatch.

## The Fix

We've added compile-time validation in the `config/2` macro that verifies:

1. The module name ends with "Command"
2. The command name atom matches the downcased module name (without "Command" suffix)

## Manual Test Instructions

To manually verify this fix works as expected:

### Test Case 1: Valid Configuration (Should Compile)

```elixir
defmodule Arca.Cli.Commands.TestCommand do
  use Arca.Cli.Command.BaseCommand

  # Correct: module is TestCommand, command name is :test
  config :test,
    name: "test",
    about: "Test command"

  @impl true
  def handle(_args, _settings, _optimus) do
    "Test command executed"
  end
end
```

### Test Case 2: Module Name Without "Command" Suffix (Should Fail)

```elixir
defmodule Arca.Cli.Commands.Test do
  use Arca.Cli.Command.BaseCommand

  config :test,
    name: "test",
    about: "Test command"
end
```

Expected error: `Command module name must end with 'Command'`

### Test Case 3: Command Name Mismatch (Should Fail)

```elixir
defmodule Arca.Cli.Commands.TestCommand do
  use Arca.Cli.Command.BaseCommand

  # Wrong: module is TestCommand, but command name is :wrong
  config :wrong,
    name: "wrong",
    about: "Test command"
end
```

Expected error: `Command name mismatch: config defines command as :wrong but module name ... expects :test`

## Expected Behavior

- Test Case 1: Should compile successfully
- Test Case 2 & 3: Should fail at compile time with the specified error messages

This verification confirms that command name mismatches are caught at compile time rather than failing silently at runtime.
