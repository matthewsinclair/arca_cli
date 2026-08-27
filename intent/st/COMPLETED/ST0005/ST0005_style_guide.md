---
verblock: "21 Mar 2025:v0.1: Arca.Cli Functional Programming Style Guide"
stp_version: 1.0.0
status: Completed
created: 20250321
completed: 20250321
---

# ST0005: Arca.Cli Functional Programming Style Guide

This document provides guidelines for applying functional programming principles in the Arca.Cli codebase. Following these conventions will ensure consistency and maintainability across the project.

## Error Handling

### Error Types

Use the standardized error type system defined in `Arca.Cli`:

```elixir
@type error_type ::
        :command_not_found
        | :command_failed
        | :invalid_argument
        | :config_error
        | :file_not_found
        | :file_not_readable
        | :file_not_writable
        | :decode_error
        | :encode_error
        | :unknown_error
```

When introducing new error conditions, extend this type rather than creating one-off error messages.

### Error Tuples

Use the three-element error tuple format for all error returns:

```elixir
{:error, error_type, reason}
```

Where:

- `error_type` is one of the defined error types
- `reason` is a descriptive message or data structure with error details

Use the `create_error/2` helper function to ensure consistency:

```elixir
create_error(:file_not_found, "Configuration file not found: #{path}")
```

### Result Type

For functions that can fail, use the standardized result type:

```elixir
@spec some_function(args) :: result(return_type)
```

Which expands to:

```elixir
@spec some_function(args) :: {:ok, return_type} | {:error, error_type(), term()}
```

### Railway-Oriented Programming

Use the `with` expression for sequences of operations that can fail:

```elixir
def process_data(input) do
  with {:ok, parsed_data} <- parse_input(input),
       {:ok, validated_data} <- validate_data(parsed_data),
       {:ok, processed_data} <- transform_data(validated_data) do
    {:ok, processed_data}
  end
end
```

This approach:

- Handles the happy path in a linear fashion
- Automatically propagates errors
- Makes the success flow easy to follow

## Function Design

### Function Decomposition

Break large functions into smaller, focused helper functions:

```elixir
# Instead of one large function:
def process_command(cmd, args) do
  # 50+ lines of complex logic
end

# Break it down:
def process_command(cmd, args) do
  with {:ok, handler} <- find_command_handler(cmd),
       {:ok, result} <- execute_command(cmd, args, handler) do
    {:ok, result}
  end
end

def find_command_handler(cmd) do
  # 10-15 lines focused on this task
end

def execute_command(cmd, args, handler) do
  # 10-15 lines focused on this task
end
```

### Context-Passing Functions

Use the `with_x` naming convention for functions that accept and return a context:

```elixir
# Original function that returns the processed value
def process_data(data) do
  # Process the data
  {:ok, processed_data}
end

# Context-passing variant
def with_processed_data(context, data_key) do
  case process_data(context[data_key]) do
    {:ok, processed} ->
      # Return the updated context
      {:ok, Map.put(context, :processed_data, processed)}
    error ->
      error
  end
end
```

This pattern enables pipeline-friendly composition:

```elixir
def process_request(context) do
  with {:ok, ctx} <- with_parsed_request(context, :raw_request),
       {:ok, ctx} <- with_validated_data(ctx, :parsed_data),
       {:ok, ctx} <- with_processed_data(ctx, :validated_data) do
    {:ok, ctx}
  end
end
```

## Pattern Matching

### Pattern Matching Over Conditionals

Prefer pattern matching over conditionals when handling different cases:

```elixir
# Instead of:
def handle_result(result) do
  if is_tuple(result) and elem(result, 0) == :ok do
    # Handle success
  else
    # Handle error
  end
end

# Prefer:
def handle_result({:ok, value}) do
  # Handle success
end

def handle_result({:error, error_type, reason}) do
  # Handle error
end
```

### Guard Clauses

Use guard clauses for type-based branching:

```elixir
def format_result(result) when is_binary(result) do
  "Result: #{result}"
end

def format_result(result) when is_integer(result) do
  "Numeric result: #{result}"
end

def format_result(result) when is_map(result) do
  "Complex result: #{inspect(result)}"
end
```

## Type Specifications

### Complete Type Specs

Add comprehensive type specifications to all public functions:

```elixir
@spec process_command(String.t(), map()) :: result(String.t())
def process_command(cmd, args) do
  # Implementation
end
```

### Type Aliases

Define type aliases for common data structures:

```elixir
@type command_args :: %{required(atom()) => String.t()}
@type command_result :: String.t() | [String.t()]

@spec execute_command(String.t(), command_args()) :: result(command_result())
```

## Testing Patterns

### Testing Railway-Oriented Functions

When testing functions that use Railway-Oriented Programming:

```elixir
test "process_data with valid input returns success" do
  assert {:ok, result} = process_data(valid_input)
  assert result == expected_output
end

test "process_data with invalid input returns appropriate error" do
  assert {:error, :invalid_argument, _reason} = process_data(invalid_input)
end
```

### Testing Context-Passing Functions

For testing context-passing functions:

```elixir
test "with_processed_data updates context with processed data" do
  context = %{raw_data: "some data"}
  assert {:ok, updated_context} = with_processed_data(context, :raw_data)
  assert Map.has_key?(updated_context, :processed_data)
  assert updated_context.processed_data == expected_processed_data
end

test "with_processed_data propagates errors" do
  context = %{raw_data: invalid_data}
  assert {:error, error_type, _reason} = with_processed_data(context, :raw_data)
  assert error_type == :invalid_argument
end
```

## Telemetry Integration

### Adding Telemetry Spans

Wrap key operations in telemetry spans:

```elixir
def process_command(cmd, args) do
  start_time = System.monotonic_time()
  metadata = %{command: cmd, args: args}

  result =
    with {:ok, handler} <- find_command_handler(cmd),
         {:ok, result} <- execute_command(cmd, args, handler) do
      {:ok, result}
    end

  duration = System.monotonic_time() - start_time
  :telemetry.execute([:arca_cli, :command], %{duration: duration}, Map.put(metadata, :result, result))

  result
end
```

## Example: Refactoring Patterns

### Before Refactoring

```elixir
def load_data(path) do
  case File.read(path) do
    {:ok, contents} ->
      case Jason.decode(contents) do
        {:ok, data} ->
          if valid_data?(data) do
            process_data(data)
          else
            "Invalid data format"
          end
        {:error, reason} ->
          "Failed to decode data: #{inspect(reason)}"
      end
    {:error, reason} ->
      "Failed to read file: #{inspect(reason)}"
  end
end
```

### After Refactoring

```elixir
@spec load_data(String.t()) :: result(processed_data_t())
def load_data(path) do
  with {:ok, contents} <- read_file(path),
       {:ok, data} <- decode_data(contents),
       {:ok, validated_data} <- validate_data(data),
       {:ok, processed_data} <- process_data(validated_data) do
    {:ok, processed_data}
  end
end

@spec read_file(String.t()) :: result(String.t())
defp read_file(path) do
  case File.read(path) do
    {:ok, contents} ->
      {:ok, contents}
    {:error, :enoent} ->
      create_error(:file_not_found, "File not found: #{path}")
    {:error, reason} ->
      create_error(:file_not_readable, "Failed to read file: #{inspect(reason)}")
  end
end

@spec decode_data(String.t()) :: result(map())
defp decode_data(contents) do
  case Jason.decode(contents) do
    {:ok, data} ->
      {:ok, data}
    {:error, reason} ->
      create_error(:decode_error, "Failed to decode data: #{inspect(reason)}")
  end
end

@spec validate_data(map()) :: result(map())
defp validate_data(data) do
  if valid_data?(data) do
    {:ok, data}
  else
    create_error(:invalid_argument, "Invalid data format")
  end
end
```

By following these guidelines, we can ensure that the Arca.Cli codebase maintains consistent patterns, improved error handling, and better maintainability through functional programming principles.
