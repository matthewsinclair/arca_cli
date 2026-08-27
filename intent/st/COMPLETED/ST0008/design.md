# Design - ST0008: Orthogonalised formatting and outputting

## Approach

Leverage Arca.Cli's existing callback system (ST0003) to create an orthogonal output system that:

1. Extends callbacks beyond REPL mode to ALL command execution
2. Adds a context structure for carrying structured output data
3. Provides style renderers for different output modes (ansi, plain, json, dump)
4. Maintains full backwards compatibility with existing commands

The system follows pure functional Elixir idioms with composable functions and pattern matching throughout.

## Design Decisions

### 1. Build on Existing Callback Infrastructure

- **Decision**: Extend the existing `Arca.Cli.Callbacks` module rather than creating new infrastructure
- **Rationale**: Minimizes complexity, leverages proven code, maintains consistency

### 2. Context-Based Data Structure

- **Decision**: Use a `%Arca.Cli.Ctx{}` struct to carry command output
- **Rationale**:
  - Provides clean separation between data and presentation
  - Enables composable pipeline processing
  - Follows established patterns from Multiplyer/MeetZaya

### 3. Semantic Output Types

- **Decision**: Use tagged tuples for output items (e.g., `{:success, msg}`, `{:table, rows, opts}`)
- **Rationale**:
  - Enables pattern matching for different renderers
  - Self-documenting output intent
  - Extensible for new output types

### 4. Automatic Style Detection

- **Decision**: Auto-detect appropriate style based on environment
- **Rationale**:
  - Plain style in tests (MIX_ENV=test)
  - Plain style for non-TTY environments
  - Respects NO_COLOR=1 environment variable
  - Fancy style for interactive terminals

### 5. Full Backwards Compatibility

- **Decision**: Support all existing command return patterns
- **Rationale**:
  - No breaking changes for existing commands
  - Gradual migration path
  - Opt-in adoption for new features

## Architecture

### Core Components

```
┌─────────────────────┐
│  Command Handler    │
│  returns: Ctx|Value │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  execute_command    │
│  checks return type │
└──────────┬──────────┘
           │
           ▼
┌────────────────────────┐
│  Callbacks System      │
│ :format_command_result │
└──────────┬─────────────┘
           │
           ▼
┌─────────────────────┐
│  Output.render      │
│  • determine_style  │
│  • apply_renderer   │
│  • format_output    │
└─────────────────────┘
           │
      ┌────┴────┐
      ▼         ▼
┌──────────┐ ┌──────────┐
│  ANSI    │ │  Plain   │
│ Renderer │ │ Renderer │
└──────────┘ └──────────┘
```

### Module Structure

```elixir
Arca.Cli.Ctx           # Context struct and composition functions
Arca.Cli.Output        # Main rendering pipeline
Arca.Cli.Output.AnsiRenderer   # Colored, formatted output
Arca.Cli.Output.PlainRenderer  # No ANSI codes
Arca.Cli.Output.JsonRenderer   # JSON structured output
Arca.Cli.Output.DumpRenderer   # Raw data inspection
```

### Data Flow

1. **Command Execution**: Handler returns either `%Ctx{}` or legacy value
2. **Callback Processing**: `:format_command_result` callback checks return type
3. **Context Rendering**: If Ctx, render through style pipeline
4. **Style Selection**: Auto-detect or use explicit style setting
5. **Output Generation**: Renderer converts structured data to strings
6. **Display**: Final output sent to appropriate destination

### Context Structure

```elixir
%Arca.Cli.Ctx{
  command: atom(),      # Command being executed
  args: map(),          # Parsed arguments
  options: map(),       # Command options
  output: list(),       # Structured output items
  errors: list(),       # Error messages
  status: atom(),       # :ok | :error | :warning
  cargo: map(),         # Command-specific data
  meta: map()           # Style, format, and other metadata
}
```

### Output Item Types

```elixir
# Messages with semantic meaning
{:success, message}
{:error, message}
{:warning, message}
{:info, message}

# Structured data
{:table, rows, headers: headers}
{:list, items, title: title}
{:text, content}

# Interactive elements (ansi mode only)
{:spinner, label, func}
{:progress, label, func}
```

## Implementation Plan

### Phase 1: Core Infrastructure

1. Add `Arca.Cli.Ctx` module with composition functions
2. Add `Arca.Cli.Output` module with rendering pipeline
3. Implement AnsiRenderer and PlainRenderer modules
4. Register `:format_command_result` callback point
5. Update `execute_command` to handle Ctx returns

### Phase 2: Style Control

1. Add environment variable support:
   - `ARCA_STYLE` to set output style (ansi, plain, json, dump)
   - `NO_COLOR` to force plain output
2. Automatic style detection based on environment

### Phase 3: Testing & Documentation

1. Add comprehensive tests for all components
2. Test backwards compatibility scenarios
3. Create migration guide for command authors
4. Add examples of context-based commands

### Phase 4: Validation

1. Migrate a sample command to use Ctx
2. Verify test fixtures work correctly
3. Performance testing
4. Integration testing with existing apps

## Alternatives Considered

### 1. Separate Output Module per Command

- **Rejected**: Too much boilerplate, violates DRY principle

### 2. Middleware Pipeline Approach

- **Rejected**: Over-engineered for the use case, harder to debug

### 3. Direct Integration into BaseCommand

- **Rejected**: Would require changes to all existing commands, breaks compatibility

### 4. External Formatting Library

- **Rejected**: Adds dependency, less control over implementation

## Success Criteria

1. ✅ Existing commands continue working without changes
2. ✅ New commands can return structured context
3. ✅ Output automatically adapts to environment (TTY, test, etc.)
4. ✅ Clean separation between data and presentation
5. ✅ Easy to add new output types and renderers
6. ✅ No performance degradation
7. ✅ Test fixtures can verify output without ANSI codes

## Example Usage

### Legacy Command (Still Works)

```elixir
def handle(args, settings, optimus) do
  "Simple string output"
end
```

### New Context-Based Command

```elixir
def handle(args, settings, optimus) do
  Arca.Cli.Ctx.new(args, settings)
  |> process_data()
  |> Ctx.add_output({:success, "Operation completed"})
  |> Ctx.add_output({:table, rows, headers: ["Name", "Value"]})
  |> Ctx.complete(:ok)
end
```

### Style Control

```bash
# Automatic style detection
mix my.cli command

# Force plain style
ARCA_STYLE=plain mix my.cli command
NO_COLOR=1 mix my.cli command

# Use JSON output
ARCA_STYLE=json mix my.cli command

# Test environment (automatic plain)
MIX_ENV=test mix my.cli command
```
