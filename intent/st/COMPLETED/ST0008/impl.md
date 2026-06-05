# Implementation - ST0008: Orthogonalised formatting and outputting

## Implementation Overview

The orthogonalized output system separates data processing, styling, and formatting concerns through a layered architecture:

1. **Context Layer** (`Arca.Cli.Ctx`) - Carries structured command output
2. **Renderer Layer** - Style-specific rendering (Plain, ANSI, JSON, Dump)
3. **Output Layer** (`Arca.Cli.Output`) - Orchestrates rendering pipeline
4. **Integration Layer** - Command execution and callback processing

## Architecture

```
Command → Context → Callbacks → Output → Renderer → Final Output
                                   ↓
                            Style Detection
                          (ENV, CLI flags, TTY)
```

## Code Examples

### Command Using Context Pattern

```elixir
defmodule Arca.Cli.Commands.SettingsAllCommand do
  def handle(_args, settings, _optimus) do
    case Arca.Cli.load_settings() do
      {:ok, loaded_settings} ->
        table_rows = settings_to_table_rows(loaded_settings)

        Ctx.new(:"settings.all", settings)
        |> Ctx.add_output({:info, "Current Configuration Settings"})
        |> Ctx.add_output({:table, table_rows, [has_headers: true]})
        |> Ctx.with_cargo(%{settings_count: map_size(loaded_settings)})
        |> Ctx.complete(:ok)

      {:error, _reason} ->
        Ctx.new(:"settings.all", settings)
        |> Ctx.add_error("Failed to load settings")
        |> Ctx.complete(:error)
    end
  end
end
```

### Pattern-Matched Command Result Processing

```elixir
# In lib/arca_cli.ex
defp process_command_result(%Ctx{} = ctx, _handler, _settings) do
  {:ok, Output.render(ctx)}
end

defp process_command_result(result, _handler, settings) when is_binary(result) do
  {:ok, apply_legacy_formatting(result, settings)}
end

defp process_command_result({:error, _} = error, _handler, _settings) do
  error
end

defp process_command_result({:nooutput, _} = result, _handler, _settings) do
  result
end
```

### Polymorphic Callback Support

```elixir
defp apply_format_callback(value, callback) when is_binary(value) do
  callback.(value)
end

defp apply_format_callback(%Ctx{} = ctx, callback) do
  callback.(ctx)
end
```

### ANSI Renderer with Owl Integration

```elixir
defp apply_cell_color(:header, cell), do: Owl.Data.tag(cell, :bright)
defp apply_cell_color(:number, cell), do: Owl.Data.tag(cell, :cyan)
defp apply_cell_color(:success, cell), do: Owl.Data.tag(cell, :green)
defp apply_cell_color(:error, cell), do: Owl.Data.tag(cell, :red)
defp apply_cell_color(:boolean_true, cell), do: Owl.Data.tag(cell, :green)
defp apply_cell_color(:boolean_false, cell), do: Owl.Data.tag(cell, :yellow)
defp apply_cell_color(_, cell), do: cell
```

## Technical Details

### Style Precedence Chain

1. Explicit style in Context metadata (highest priority)
2. Environment variables (`NO_COLOR`, `ARCA_STYLE`)
3. Test environment detection (`MIX_ENV=test`)
4. TTY availability check (lowest priority)

### Output Types

- **Messages**: `:success`, `:error`, `:warning`, `:info`, `:text`
- **Structured**: `:table`, `:list`
- **Interactive**: `:spinner`, `:progress`

### Table Rendering

Tables support two formats:

1. List of lists: `[["Name", "Age"], ["Alice", "30"]]`
2. List of maps: `[%{name: "Alice", age: 30}]`

Headers are indicated via the `has_headers: true` option.

### Environment Variables for Style Control

Output style is controlled via environment variables:

- `ARCA_STYLE`: Set output style to `ansi`, `plain`, `json`, or `dump`
- `NO_COLOR`: When set (to any value except "", "0", or "false"), forces plain style

Examples:

```bash
# Use JSON output
ARCA_STYLE=json arca.cli sys.info

# Disable colors
NO_COLOR=1 arca.cli sys.info

# Use dump format for debugging
ARCA_STYLE=dump arca.cli settings.all
```

## Challenges & Solutions

### Challenge 1: ANSI Codes Breaking Table Column Widths

**Problem**: Raw ANSI escape sequences in cell content caused Owl to miscalculate column widths, resulting in misaligned tables.

**Solution**: Use `Owl.Data.tag/2` instead of raw `IO.ANSI` functions. Owl's tagging system preserves the actual string length for width calculations while applying colors during rendering.

### Challenge 2: Header Detection in Tables

**Initial Approach**: Tried heuristic detection (checking if first row contains only strings).

**Problem**: Unreliable and could misidentify data rows as headers.

**Solution**: Explicit `has_headers: true` option in table output tuple. Commands explicitly indicate when first row contains headers.

### Challenge 3: Test Pollution from Callbacks

**Problem**: Callbacks registered in tests were leaking between test runs, causing intermittent failures with "[LEGACY]" prefixes appearing randomly.

**Solution**:

- Made polymorphic formatter test synchronous (`async: false`)
- Added proper cleanup with `on_exit` callbacks
- Save and restore Application environment in test setup/teardown

### Challenge 4: Mix.env() Not Available in Production

**Problem**: Initial implementation used `Mix.env()` for test detection, which isn't available in production builds.

**Solution**: Use `System.get_env("MIX_ENV")` instead, which works in all environments.

### Challenge 5: Backwards Compatibility

**Problem**: Need to support both legacy string returns and new Context returns without breaking existing commands.

**Solution**: Pattern-matched dispatch in `process_command_result/3` that detects return type and applies appropriate processing path.

### Challenge 6: Style Naming Confusion

**Problem**: Original names ("fancy", "plain", "dump") weren't intuitive or standard.

**Solution**: Renamed to industry-standard terms:

- `fancy` → `ansi` (clear indication of ANSI color support)
- `plain` → `plain` (unchanged)
- Added `json` for structured output
- Kept `dump` for debugging

## Migration Path

Commands can be migrated incrementally:

1. **Phase 1**: Existing commands continue returning strings (fully supported)
2. **Phase 2**: New commands use Context pattern
3. **Phase 3**: Gradually migrate existing commands as needed

Example migration:

```elixir
# Before
def handle(args, settings, optimus) do
  result = process_data()
  formatted = format_as_string(result)
  IO.puts(formatted)
  formatted
end

# After
def handle(args, settings, optimus) do
  result = process_data()

  Ctx.new(:my_command, settings)
  |> Ctx.add_output({:info, "Processing complete"})
  |> Ctx.add_output({:table, result, [has_headers: true]})
  |> Ctx.complete(:ok)
end
```

## Performance Considerations

- Context creation is lightweight (simple struct initialization)
- Rendering is lazy - only happens when Output.render is called
- Callback processing uses pattern matching for efficiency
- No performance regression observed in testing (337 tests run in ~2.3s)

## Testing Strategy

- Unit tests for each renderer verify output format
- Integration tests verify end-to-end command execution
- Environment variable isolation prevents test pollution
- Polymorphic callbacks tested with both string and Context inputs
- Edge cases (nil output, malformed data) handled gracefully
