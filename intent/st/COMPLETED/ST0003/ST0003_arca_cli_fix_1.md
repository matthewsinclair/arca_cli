---
verblock: "20 Mar 2025:v0.1: Matthew Sinclair - Updated via STP upgrade"
stp_version: 1.0.0
status: Not Started
created: 20250320
completed:
---

# Arca.CLI Changes for OutputContext Integration

## Problem

We need a way for external applications like Multiplyer to customize the output formatting in Arca.CLI's REPL without creating circular dependencies.

## Solution

Add a generic formatter callback system to Arca.CLI that any application can implement.

## Required Changes

### 1. Add a callback registry to Arca.CLI

```elixir
# In deps/arca_cli/lib/arca_cli/callbacks.ex

defmodule Arca.Cli.Callbacks do
  @moduledoc """
  Callback registry for extending Arca.CLI functionality.

  This module allows other applications to register callbacks for various
  extension points in Arca.CLI without creating circular dependencies.
  """

  @doc """
  Register a callback function for a specific event.

  ## Parameters

  - `event`: The event name (atom)
  - `callback`: The callback function (function)

  ## Returns

  `:ok`

  ## Examples

      iex> Arca.Cli.Callbacks.register(:format_output, &MyApp.format_output/1)
      :ok
  """
  def register(event, callback) when is_atom(event) and is_function(callback) do
    callbacks = Application.get_env(:arca_cli, :callbacks, %{})
    event_callbacks = Map.get(callbacks, event, [])
    updated = Map.put(callbacks, event, [callback | event_callbacks])
    Application.put_env(:arca_cli, :callbacks, updated)
    :ok
  end

  @doc """
  Execute all callbacks for a specific event.

  Callbacks are executed in reverse registration order (last registered, first executed).
  Each callback can return {:halt, result} to stop the chain and use that result,
  or {:cont, value} to pass a value to the next callback.

  ## Parameters

  - `event`: The event name (atom)
  - `initial`: The initial value to pass to the first callback

  ## Returns

  The final result after all callbacks have been executed, or the initial value
  if no callbacks are registered.

  ## Examples

      iex> Arca.Cli.Callbacks.execute(:format_output, "Hello")
      "FORMATTED: Hello"
  """
  def execute(event, initial) do
    callbacks = Application.get_env(:arca_cli, :callbacks, %{})
    event_callbacks = Map.get(callbacks, event, [])

    # Execute callbacks in reverse order (last registered, first executed)
    Enum.reduce_while(event_callbacks, {:cont, initial}, fn callback, {:cont, acc} ->
      case callback.(acc) do
        {:halt, result} -> {:halt, result}  # Stop the chain and return this result
        {:cont, value} -> {:cont, {:cont, value}}  # Continue with this value
        other -> {:cont, {:cont, other}}  # Treat any other return as {:cont, value}
      end
    end)
    |> case do
      {:cont, value} -> value  # Return the final value if chain completed
      result -> result  # Return the halted result
    end
  end

  @doc """
  Check if any callbacks are registered for a specific event.

  ## Parameters

  - `event`: The event name (atom)

  ## Returns

  `true` if callbacks are registered, `false` otherwise

  ## Examples

      iex> Arca.Cli.Callbacks.has_callbacks?(:format_output)
      true
  """
  def has_callbacks?(event) do
    callbacks = Application.get_env(:arca_cli, :callbacks, %{})
    event_callbacks = Map.get(callbacks, event, [])
    length(event_callbacks) > 0
  end
end
```

### 2. Modify Arca.Cli.Repl to use the callback system

```elixir
# In deps/arca_cli/lib/arca_cli/repl/repl.ex

# Replace the existing print/1 function with this version
defp print(out) when is_tuple(out), do: out

defp print(out) do
  # Check if we have any format_output callbacks registered
  if Arca.Cli.Callbacks.has_callbacks?(:format_output) do
    # Execute all format_output callbacks
    formatted = Arca.Cli.Callbacks.execute(:format_output, out)

    # Print the formatted output
    IO.puts(formatted)

    # Return the original output (for tee-like behavior)
    out
  else
    # Fall back to the original implementation
    Utils.print(out)
  end
end
```

## How to Implement in Multiplyer

Once the above changes are made to Arca.CLI, we can integrate our OutputContext system:

```elixir
# In Multiplyer.Cli.ReplHandler

@doc """
Register the OutputContext formatter with Arca.Cli.Callbacks.
"""
def register_with_arca do
  if Code.ensure_loaded?(Arca.Cli.Callbacks) do
    # Register a callback for format_output
    Arca.Cli.Callbacks.register(:format_output, fn output ->
      # Get the current format from ReplHandler
      format = current_format()

      # Format the output
      formatted = format_result(output, format)

      # Return {:halt, result} to stop the callback chain
      {:halt, formatted}
    end)

    :ok
  else
    {:error, :callback_system_not_available}
  end
end
```

```elixir
# In Multiplyer.Application.start/2

# Register the ReplHandler with Arca.Cli.Callbacks
if Code.ensure_loaded?(Multiplyer.Cli.ReplHandler) do
  Multiplyer.Cli.ReplHandler.register_with_arca()
end
```

## Benefits of This Approach

1. **No Circular Dependencies**: Arca.CLI has no knowledge of Multiplyer
2. **Clean Extension**: Uses a callback system for extensions
3. **Maintainability**: Each codebase maintains its own concerns
4. **Flexibility**: Multiple applications can register callbacks
5. **Fail-Safe**: Falls back to default behavior if callbacks aren't available

## Implementation Steps

1. Add the `Arca.Cli.Callbacks` module to Arca.CLI
2. Modify the `print/1` function in Arca.Cli.Repl
3. Add `register_with_arca/0` to Multiplyer.Cli.ReplHandler
4. Update Multiplyer's Application module to register the callback at startup
