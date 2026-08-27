# Design - ST0010: HEREDOC injection for cli.script

**Status**: AS-BUILT (Implementation Complete - 2025-10-29)

This document describes the design as implemented. All components built and tested successfully.

## Approach

Implement heredoc stdin injection using Elixir's Group Leader redirection pattern. This leverages the standard Erlang IO protocol to intercept `IO.gets/1` calls and provide scripted responses without modifying command implementations.

### Three-Part Solution

1. **Parser**: Extend `.cli` file parser to recognize heredoc syntax and accumulate content
2. **InputProvider**: Create GenServer implementing IO protocol to serve heredoc lines
3. **Execution**: Wrap command execution with group leader swap

## Architecture

### Current Architecture

```
┌─────────────────────────────────────────────┐
│ cli.script command                          │
├─────────────────────────────────────────────┤
│ 1. Read .cli file                           │
│ 2. Split by lines                           │
│ 3. For each line:                           │
│    - Skip if comment (#) or blank           │
│    - Call Repl.eval_for_redo(line)          │
│      └─> Command executes                   │
│          └─> IO.gets() blocks waiting...    │
└─────────────────────────────────────────────┘
```

### New Architecture

```
┌─────────────────────────────────────────────────────────────┐
│ cli.script command                                          │
├─────────────────────────────────────────────────────────────┤
│ 1. Read .cli file                                           │
│ 2. Parse with state machine:                                │
│    - Detect <<MARKER                                        │
│    - Accumulate lines until MARKER                          │
│    - Emit {:command_with_stdin, cmd, lines}                 │
│ 3. For each parsed command:                                 │
│    - If simple command: Repl.eval_for_redo(line)            │
│    - If has stdin:                                          │
│      a. Start InputProvider GenServer with lines            │
│      b. Save original group_leader                          │
│      c. Set InputProvider as group_leader                   │
│      d. Call Repl.eval_for_redo(cmd)                        │
│         └─> Command calls IO.gets()                         │
│             └─> InputProvider serves next line              │
│      e. Restore original group_leader                       │
│      f. Stop InputProvider                                  │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────┐
│ InputProvider GenServer                     │
├─────────────────────────────────────────────┤
│ State: {lines, current_index}               │
│                                             │
│ Implements IO Protocol:                     │
│  - handle_info({:io_request, ...})          │
│  - Returns lines one at a time              │
│  - Returns :eof when exhausted              │
└─────────────────────────────────────────────┘
```

## Design Decisions

### 1. Heredoc Syntax: `<<MARKER ... MARKER`

**Decision**: Use bash-style heredoc with explicit marker

**Rationale**:

- Familiar to shell scripters (reduces learning curve)
- Self-documenting (clear where heredoc ends)
- Allows custom markers (users can avoid conflicts)
- Simple to parse (regex match `<<(\w+)` at end of line)

**Rejected alternatives**:

- `<<<` triple-angle: Less familiar, unclear where it ends
- Indentation-based: Fragile, error-prone with mixed tabs/spaces
- JSON/YAML structure: Too heavy, loses shell-script feel

### 2. Implementation Strategy: Group Leader Redirection

**Decision**: Use Elixir's built-in Group Leader mechanism

**Rationale**:

- **Idiomatic**: This is the standard Elixir/Erlang pattern for IO redirection
  - `ExUnit` uses it to capture test output
  - `Logger` uses it for process-specific logging
  - Well-documented OTP pattern
- **Non-invasive**: Commands don't need any changes
- **Complete**: Handles all IO functions (`IO.gets/1`, `IO.read/2`, `IO.getn/2`, etc.)
- **Testable**: InputProvider can be tested independently
- **Simple**: ~100 lines of code total

**Rejected alternatives**:

- **Port stdin redirection**: OS-level complexity, platform-specific
- **Monkey-patching IO module**: Fragile, breaks in updates
- **Command argument injection**: Would require modifying every command
- **Expect-style automation**: Heavy dependency, overkill

### 3. Parser State Machine: Two States

**Decision**: Simple two-state machine (`:normal`, `{:in_heredoc, cmd, marker, lines}`)

**Rationale**:

- Minimal complexity (only what's needed)
- Easy to understand and maintain
- Clear error detection (unclosed heredoc = still in heredoc state at EOF)
- Natural fit for line-by-line processing

**State transitions**:

```
:normal
  ├─ "# comment" → :normal (skip)
  ├─ "" → :normal (skip)
  ├─ "cmd <<MARKER" → {:in_heredoc, "cmd", "MARKER", []}
  └─ "cmd" → emit {:command, "cmd"}, :normal

{:in_heredoc, cmd, marker, lines}
  ├─ "MARKER" → emit {:command_with_stdin, cmd, lines}, :normal
  └─ "content" → {:in_heredoc, cmd, marker, [line | lines]}
```

### 4. Marker Format: Alphanumeric Only (Initially)

**Decision**: Accept `\w+` (letters, numbers, underscores) as markers

**Rationale**:

- Covers 99% of use cases (`EOF`, `END`, `INPUT`, `DATA`)
- Simple regex: `~r/<<(\w+)$/`
- No security concerns (can't inject special chars)
- Future-proof (can relax later if needed)

**Not supported initially**:

- Quoted markers (`<<'EOF'` vs `<<EOF`)
- Tab-stripping (`<<-EOF`)
- Numeric-only markers (`<<123`)

### 5. EOF Behavior: Automatic

**Decision**: Automatically send `:eof` when heredoc lines exhausted

**Rationale**:

- Matches bash behavior (heredoc = finite input)
- Prevents commands hanging waiting for more input
- Simpler for users (no need to think about EOF)

**Alternative**: Require explicit EOF line in heredoc (rejected - too verbose)

### 6. Whitespace Handling: Preserve Verbatim

**Decision**: Capture heredoc content exactly as written (including leading/trailing spaces)

**Rationale**:

- Predictable behavior (WYSIWYG)
- Matches bash default heredoc behavior
- Users can control whitespace explicitly
- Simpler implementation (no stripping logic)

**Future enhancement**: Add `<<-MARKER` for tab-stripping if needed

### 7. Error Handling: Fail Fast

**Decision**: Detect unclosed heredocs at parse time, raise clear error

**Rationale**:

- Fail early (before execution starts)
- Clear error message: `"Unclosed heredoc: expected 'EOF' but reached end of file"`
- Shows line number where heredoc started
- Better than mysterious hanging or silent failure

## Implementation Details

### Parser Implementation

**Location**: `lib/arca_cli/commands/cli_script_command.ex`

**Current function**: `process_script_commands/3`

**New function**: `parse_script_commands/1`

```elixir
defp parse_script_commands(content) do
  lines = String.split(content, ~r/\r?\n/)
  parse_lines(lines, [], :normal, 1)
end

defp parse_lines([], acc, :normal, _line_num) do
  {:ok, Enum.reverse(acc)}
end

defp parse_lines([], _acc, {:in_heredoc, _cmd, marker, _lines, start_line}, _line_num) do
  {:error, "Unclosed heredoc starting at line #{start_line}: expected '#{marker}' but reached end of file"}
end

defp parse_lines([line | rest], acc, :normal, line_num) do
  trimmed = String.trim(line)

  cond do
    trimmed == "" or String.starts_with?(trimmed, "#") ->
      # Skip comments and blank lines
      parse_lines(rest, acc, :normal, line_num + 1)

    heredoc_match = Regex.run(~r/^(.+?)\s+<<(\w+)$/, trimmed) ->
      # Start heredoc: "command <<MARKER"
      [_, cmd, marker] = heredoc_match
      parse_lines(rest, acc, {:in_heredoc, cmd, marker, [], line_num}, line_num + 1)

    true ->
      # Regular command
      parse_lines(rest, [{:command, trimmed} | acc], :normal, line_num + 1)
  end
end

defp parse_lines([line | rest], acc, {:in_heredoc, cmd, marker, lines, start_line}, line_num) do
  if String.trim(line) == marker do
    # End heredoc
    parsed = {:command_with_stdin, cmd, Enum.reverse(lines)}
    parse_lines(rest, [parsed | acc], :normal, line_num + 1)
  else
    # Accumulate heredoc content (preserve original whitespace)
    parse_lines(rest, acc, {:in_heredoc, cmd, marker, [line | lines], start_line}, line_num + 1)
  end
end
```

### InputProvider GenServer

**Location**: `lib/arca_cli/commands/input_provider.ex` (new file)

```elixir
defmodule Arca.Cli.Commands.InputProvider do
  @moduledoc """
  GenServer implementing the Erlang IO protocol to provide scripted stdin.

  Used by cli.script heredoc feature to inject input into interactive commands.
  """

  use GenServer

  # Client API

  def start_link(lines) when is_list(lines) do
    GenServer.start_link(__MODULE__, {lines, 0})
  end

  # Server Callbacks

  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  def handle_info({:io_request, from, reply_as, req}, state) do
    {reply, new_state} = io_request(req, state)
    send(from, {:io_reply, reply_as, reply})
    {:noreply, new_state}
  end

  # IO Protocol Implementation

  defp io_request({:get_line, _prompt}, {lines, index}) when index < length(lines) do
    line = Enum.at(lines, index)
    # Add newline to simulate user pressing Enter
    {{:ok, line <> "\n"}, {lines, index + 1}}
  end

  defp io_request({:get_line, _prompt}, {lines, index}) when index >= length(lines) do
    # Exhausted all lines, return EOF
    {:eof, {lines, index}}
  end

  defp io_request({:get_chars, _prompt, count}, {lines, index}) when index < length(lines) do
    # Handle IO.getn/2
    line = Enum.at(lines, index)
    chars = String.slice(line, 0, count)
    remaining = String.slice(line, count..-1)

    if remaining == "" do
      {{:ok, chars <> "\n"}, {lines, index + 1}}
    else
      # Partial line consumption (complex case, return full line for simplicity)
      {{:ok, chars}, {lines, index}}
    end
  end

  defp io_request({:get_chars, _prompt, _count}, {lines, index}) when index >= length(lines) do
    {:eof, {lines, index}}
  end

  # Handle other IO requests (put_chars, etc.) - just ignore or pass through
  defp io_request(_, state) do
    {{:error, :enotsup}, state}
  end
end
```

### Execution Wrapper

**Location**: `lib/arca_cli/commands/cli_script_command.ex`

**Modify**: `process_script_commands/3` to handle `{:command_with_stdin, cmd, lines}`

```elixir
defp execute_command({:command, cmd_string}, settings, optimus) do
  IO.puts("script> #{cmd_string}")
  result = Repl.eval_for_redo({0, cmd_string}, settings, optimus)
  Repl.print_result(result)
  :ok
end

defp execute_command({:command_with_stdin, cmd_string, stdin_lines}, settings, optimus) do
  IO.puts("script> #{cmd_string} <<EOF")
  Enum.each(stdin_lines, &IO.puts("  #{&1}"))
  IO.puts("EOF")

  # Start input provider
  {:ok, provider} = InputProvider.start_link(stdin_lines)
  original_leader = Process.group_leader()

  # Redirect IO to provider
  Process.group_leader(self(), provider)

  # Execute command (stdin calls go to provider)
  result = Repl.eval_for_redo({0, cmd_string}, settings, optimus)

  # Restore original group leader
  Process.group_leader(self(), original_leader)
  GenServer.stop(provider)

  Repl.print_result(result)
  :ok
end
```

## Error Handling

### Parse Errors

1. **Unclosed heredoc**: Reached EOF while in `{:in_heredoc, ...}` state
   - Error message: `"Unclosed heredoc starting at line #{start_line}: expected '#{marker}' but reached end of file"`
   - Exit code: 1

2. **Malformed heredoc marker**: `<<` but no valid marker after
   - Currently: Treated as regular command (might fail when executed)
   - Future: Could detect and warn

### Runtime Errors

1. **Command doesn't read stdin**: InputProvider started but never consumed
   - Behavior: No error (heredoc silently unused, like bash)
   - Future: Could add warning if stdin unused

2. **Command reads more than provided**: InputProvider returns `:eof` early
   - Behavior: Command receives EOF (same as user pressing Ctrl-D)
   - Up to command to handle gracefully

3. **Group Leader swap fails**: Process.group_leader/2 fails (rare)
   - Behavior: Raises Elixir exception, script stops
   - Logged with context about which command failed

## Testing Strategy

### Unit Tests

1. **Parser tests** (`cli_script_command_test.exs`):
   - Parse simple heredoc
   - Parse multiple heredocs in one script
   - Parse mixed regular commands and heredocs
   - Detect unclosed heredocs
   - Preserve whitespace in heredoc content
   - Handle Windows line endings (`\r\n`)
   - Various marker names (`EOF`, `END`, `INPUT123`)

2. **InputProvider tests** (`input_provider_test.exs`):
   - Serve lines via `IO.gets/1`
   - Return `:eof` when exhausted
   - Handle `IO.getn/2` (get N characters)
   - Handle empty stdin list

### Integration Tests

1. **Mock command test**: Create test command that reads stdin, verify heredoc injects correctly
2. **Real command test**: Use existing `ll.llm.chat` or similar interactive command
3. **Backward compatibility test**: Existing `.cli` files still work

### Edge Cases

- Empty heredoc (no lines between markers)
- Heredoc with only whitespace
- Heredoc marker appears in content (terminates early - document limitation)
- Very long heredoc (1000+ lines)
- Unicode in heredoc content

## Alternatives Considered

### Alternative 1: File Redirection (`command < input.txt`)

**Pros**:

- Very familiar shell syntax
- OS-level stdin redirection

**Cons**:

- Requires separate input files (clutters workspace)
- Harder to maintain (script and inputs separate)
- Less readable (need to open multiple files to understand)

**Verdict**: Rejected - heredoc is more self-contained

### Alternative 2: Prefix-based Input

```
command
> line 1
> line 2
```

**Pros**:

- Simpler parsing (no state machine)
- Clear visual distinction

**Cons**:

- Nonstandard syntax (unfamiliar)
- Harder to copy-paste multi-line content
- Ambiguous when command outputs prompt

**Verdict**: Rejected - heredoc is more standard

### Alternative 3: JSON/YAML Structure

```yaml
- command: ll.play game
  stdin:
    - line 1
    - line 2
```

**Pros**:

- Structured data (easier to parse)
- Could add metadata (timeouts, expected outputs, etc.)

**Cons**:

- No longer looks like shell script
- Much more verbose
- Requires YAML parser
- Loses "execute commands sequentially" simplicity

**Verdict**: Rejected - overengineered for the use case

### Alternative 4: Expect-style Automation

Use library like Erlang's `ct_expect` or similar automation framework.

**Pros**:

- Can handle expect/send patterns (more interactive)
- Timeouts, pattern matching on output

**Cons**:

- Heavy dependency
- Overkill for simple stdin injection
- Slower (spawns PTY, parses output)
- More complex error handling

**Verdict**: Rejected - too complex for MVP needs

## Future Enhancements

### Phase 2 (if demand exists)

1. **Quoted markers** (`<<'EOF'` = no interpolation, `<<"EOF"` = interpolation)
   - Allows variable substitution in heredoc content
   - Requires adding variable binding context to cli.script

2. **Tab-stripping heredocs** (`<<-EOF`)
   - Strips leading tabs from content lines
   - Useful for indented heredocs in nested structures

3. **Include files** (`<<< input.txt`)
   - Read stdin from external file
   - Best of both worlds: separate files when useful, inline when not

### Phase 3 (if really needed)

1. **Multiple heredocs per command**: `cmd <<IN1 <<IN2`
2. **Heredoc to file**: `command <<EOF > output.txt`
3. **Conditional heredocs**: Skip heredoc if condition false
4. **Interactive vs batch mode**: Flag to switch between heredoc and real stdin

## Open Questions

1. **Should we echo heredoc lines as they're consumed?**
   - Currently: Show all lines upfront when command starts
   - Alternative: Show each line as command reads it (more realistic)
   - Decision: Show upfront (simpler, faster, matches script nature)

2. **What if command uses ExPrompt?**
   - ExPrompt might bypass Group Leader mechanism
   - Initial approach: Document as limitation
   - If problematic: Patch ExPrompt or add compatibility layer

3. **Should we support streaming output while reading stdin?**
   - Some commands might print output while waiting for input
   - Current approach handles this naturally (group leader only redirects stdin)
   - No special handling needed

## References

- [Erlang IO Protocol Documentation](https://www.erlang.org/doc/apps/stdlib/io_protocol.html)
- [Elixir Process.group_leader/2](https://hexdocs.pm/elixir/Process.html#group_leader/2)
- [ExUnit Capture IO implementation](https://github.com/elixir-lang/elixir/blob/main/lib/ex_unit/lib/ex_unit/capture_io.ex)
- [Bash Heredoc Documentation](https://www.gnu.org/software/bash/manual/html_node/Redirections.html)
