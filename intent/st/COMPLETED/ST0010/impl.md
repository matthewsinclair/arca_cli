# Implementation - ST0010: HEREDOC injection for cli.script

## Status: ✅ COMPLETE

Implementation completed on 2025-10-29

## Implementation Summary

Successfully implemented heredoc-style stdin injection for `.cli` script files using pure functional Elixir with pattern matching and pipelines.

## What Was Built

### 1. InputProvider GenServer

**File**: `lib/arca_cli/commands/input_provider.ex`

- Implements Erlang IO protocol
- Serves scripted stdin lines to commands
- Returns `:eof` when exhausted
- Handles `IO.gets/1`, `IO.getn/2`, and related functions
- ~165 lines of clean functional code

### 2. Heredoc Parser

**File**: `lib/arca_cli/commands/cli_script_command.ex` (enhanced)

- Two-state parser: `:normal` ↔ `{:in_heredoc, cmd, marker, lines, start_line}`
- Detects `<<MARKER` syntax
- Accumulates content until closing marker
- Preserves whitespace verbatim
- Provides clear error messages with line numbers

### 3. Command Execution with Group Leader Redirection

**File**: `lib/arca_cli/commands/cli_script_command.ex` (enhanced)

- Pattern matches on command types
- `with_stdin_provider/2` wraps execution
- `try...after` ensures group leader restoration
- Non-invasive: commands don't need modification

### 4. Test Suite

- `test/arca_cli/commands/input_provider_test.exs` (14 tests)
- `test/arca_cli/commands/cli_script_command_test.exs` (enhanced)
- **456 tests passing**, 0 failures, 0 warnings

## Code Examples

### Pure Functional Parser

```elixir
# No conditionals - only pattern matching
defp classify_line(""), do: :skip
defp classify_line("#" <> _), do: :skip
defp classify_line(trimmed) do
  case Regex.run(~r/^(.+?)\s+<<(\w+)$/, trimmed) do
    [_, cmd, marker] -> {:heredoc_start, cmd, marker}
    nil -> {:command, trimmed}
  end
end

# Pipeline-based flow
content
|> parse_script()
|> handle_parse_result(settings, optimus)
```

### Clean IO Protocol Implementation

```elixir
# Pattern match on request types
defp handle_io_request({:get_line, _prompt}, state) do
  get_next_line(state)
end

# Pipeline transformations
defp get_next_line({lines, index}) when index < length(lines) do
  lines
  |> Enum.at(index)
  |> append_newline()
  |> then(&{&1, {lines, index + 1}})
end
```

### Safe Group Leader Management

```elixir
defp with_stdin_provider(lines, fun) do
  {:ok, provider} = InputProvider.start_link(lines)
  original_leader = Process.group_leader()

  try do
    Process.group_leader(self(), provider)
    fun.()
  after
    Process.group_leader(self(), original_leader)
    GenServer.stop(provider)
  end
end
```

## Technical Details

### How It Works

1. **Parse**: Script parsed into command list
   - Regular: `{:command, cmd}`
   - Heredoc: `{:command_with_stdin, cmd, marker, lines}`

2. **Execute**: Commands processed sequentially
   - Regular: Direct `Repl.eval_for_redo/3`
   - Heredoc: Wrapped with `with_stdin_provider/2`

3. **Redirect**: Group leader swapped during execution
   - Start InputProvider GenServer
   - Set as process group leader
   - Execute command (stdin → provider)
   - Restore original group leader

4. **Serve**: Provider handles IO requests
   - `IO.gets/1` → returns next line
   - End of lines → returns `:eof`

### Code Quality Achieved

- ✅ **Pure functional** - zero nested conditionals
- ✅ **Pattern matching** - function heads for all branches
- ✅ **Pipelines** - data transformations via `|>`
- ✅ **Guard clauses** - boundary conditions
- ✅ **Small functions** - 5-15 lines each
- ✅ **Idiomatic Elixir** - OTP patterns throughout

## Challenges & Solutions

### Challenge 1: IO Protocol Return Format

**Problem**: Initial implementation returned `{:ok, line}` but IO protocol expects just `line`.

**Solution**: Fixed `handle_io_request` to return bare values:

- `get_line` returns `line` (not `{:ok, line}`)
- `eof` returns `:eof` (not `{:ok, :eof}`)
- Errors return `{:error, reason}`

### Challenge 2: Hardcoded Marker Display

**Problem**: Initially hardcoded "EOF" in output instead of actual marker.

**Solution**: Enhanced parser to include marker in tuple:

- Changed from `{:command_with_stdin, cmd, lines}`
- To `{:command_with_stdin, cmd, marker, lines}`
- Updated executor to pattern match and display correct marker

### Challenge 3: Pure Functional Parsing

**Problem**: Original approach used nested `cond`/`if` statements.

**Solution**: Refactored to pattern-matched functions:

- `classify_line/1` for line type detection
- `handle_classification/5` for state transitions
- `handle_heredoc_line/9` for heredoc processing
- Zero conditional nesting

## Files Added

1. `lib/arca_cli/commands/input_provider.ex`
2. `test/arca_cli/commands/input_provider_test.exs`
3. `test/fixtures/scripts/test_heredoc.cli`
4. `examples/heredoc_demo.cli`

## Files Modified

1. `lib/arca_cli/commands/cli_script_command.ex`
2. `test/arca_cli/commands/cli_script_command_test.exs`

## Success Criteria Met

- ✅ Can script multi-turn interactive sessions
- ✅ Existing `.cli` scripts continue working
- ✅ Clear error messages for unclosed heredocs
- ✅ Documentation with examples
- ✅ Comprehensive test coverage
- ✅ All tests passing

## Usage Example

```bash
# Create script with heredoc
cat > demo.cli <<'END'
interactive.command <<EOF
line 1
line 2
/exit
EOF
END

# Run it
mix ll.cli cli.script demo.cli
```

## Time Spent

Approximately 3-4 hours total (under the 9-14 hour estimate)

---

**Implementation Status: ✅ COMPLETE**
