---
verblock: "29 Oct 2025:v0.2: Matthew Sinclair - Completed implementation"
intent_version: 2.2.0
status: Completed
created: 20251029
completed: 20251029
---

# ST0010: HEREDOC injection for cli.script

## Objective

Add heredoc-style stdin injection to `.cli` script files, enabling automation of interactive commands (like `ll.play`, `ll.agent.engage`, `ll.llm.chat`) without requiring manual input.

## Context

### The Problem

Currently, `cli.script` can execute CLI commands from `.cli` files but cannot inject input into interactive commands. When a command expects user input via `IO.gets/1` or similar, the script execution blocks waiting for input that never comes.

Example that doesn't work today:

```
ll.play the_conundra --trace
Hello Sam!          # This becomes another command (fails)
What do you think?  # This also becomes another command (fails)
/exit               # This also becomes another command (fails)
```

This prevents:

- Automated testing of interactive narrative flows
- Scripted demos and recordings
- CI/CD testing of agent engagement scenarios
- Batch processing of LLM conversations

### The Solution

Add bash-style heredoc syntax to `.cli` files:

```
ll.play the_conundra --trace <<EOF
Hello Sam!
What do you think?
/exit
EOF
```

This uses Elixir's Group Leader redirection pattern to inject stdin without modifying commands.

### Design Principles

1. **Simple**: MVP supports basic `<<MARKER ... MARKER` syntax only
2. **Idiomatic**: Uses Elixir's Group Leader mechanism (standard IO redirection pattern)
3. **Self-contained**: Commands don't need to know about heredocs
4. **Backward compatible**: Existing `.cli` files continue to work unchanged
5. **Consistent**: Follows shell scripting conventions (heredoc is familiar to users)

## Syntax Specification

### Basic Heredoc

```
command <<MARKER
line 1
line 2
line 3
MARKER
```

- Marker must appear at end of command line after a space
- Content lines captured verbatim (preserving whitespace)
- Closing marker must appear on its own line
- Each line sent to command's stdin as if user typed it + Enter
- EOF sent automatically after last line

### Supported Markers

Initial implementation supports any alphanumeric marker (typically `EOF`, `END`, `INPUT`, etc.)

### Example Use Cases

**Interactive narrative:**

```
ll.world.mount lecarre.circus
ll.play the_conundra --trace <<EOF
Hello Sam!
What do you think about this situation?
/exit
EOF
```

**Agent engagement:**

```
ll.agent.engage my_agent <<EOF
analyze this data
show me the results
/done
EOF
```

**LLM chat session:**

```
ll.llm.chat <<EOF
What is the meaning of life?
Can you elaborate?
/exit
EOF
```

## Scope & Limitations

### MVP (Phase 1)

- ✅ Single heredoc per command
- ✅ Simple `<<MARKER` syntax
- ✅ Works with standard Elixir `IO.gets/1`, `IO.read/2`, etc.
- ✅ Clear error messages for unclosed heredocs
- ✅ Backward compatible with existing `.cli` files

### Known Limitations

- ❌ No nested heredocs
- ❌ No variable interpolation in heredoc content
- ❌ No support for commands using `ExPrompt` or custom IO (may work, but not guaranteed)
- ❌ If heredoc content contains the EOF marker, it terminates early (use different marker)
- ❌ No indentation stripping (`<<-` style not supported in v1)

### Not in Scope (Future Enhancements)

- Multiple heredocs per command
- Quoted markers (`<<'EOF'` vs `<<EOF`) for interpolation control
- Tab-stripping heredocs (`<<-EOF`)
- Include external files (`<<< file.txt`)
- Conditional heredocs

## Implementation Overview

### Key Components

1. **Parser Enhancement** (`cli_script_command.ex`)
   - State machine: `:normal` ↔ `:in_heredoc`
   - Detects `<<MARKER` at end of command line
   - Accumulates lines until closing `MARKER`
   - Returns `{:command_with_stdin, cmd, stdin_lines}`

2. **InputProvider GenServer** (new module)
   - Implements Erlang IO protocol
   - Serves heredoc lines when command calls `IO.gets/1`
   - Returns `:eof` when exhausted

3. **Group Leader Redirection** (execution in `cli_script_command.ex`)
   - Spawns `InputProvider` with heredoc lines
   - Temporarily sets it as process group leader
   - Executes command (stdin calls redirected to provider)
   - Restores original group leader after execution

### Why This Approach?

**Elixir-idiomatic**: Group leader pattern is the standard way to redirect IO in Elixir/Erlang (used by ExUnit, Logger, etc.)

**Non-invasive**: Commands don't need modification - they continue using `IO.gets/1` normally

**Testable**: InputProvider can be tested independently; existing command tests unaffected

**Simple**: No complex piping, no OS-level stdin manipulation, no Port hackery

## Related Steel Threads

- None currently

## Success Criteria

**All criteria met - 2025-10-29**

- [x] Can script multi-turn `ll.play` sessions
- [x] Can script `ll.agent.engage` dialogs
- [x] Can script `ll.llm.chat` conversations
- [x] Existing `.cli` scripts continue working unchanged
- [x] Clear error message for unclosed heredocs
- [x] Documentation with examples
- [x] Test coverage for heredoc parsing and execution

## Context for LLM

This document represents a single steel thread - a self-contained unit of work focused on implementing a specific piece of functionality. When working with an LLM on this steel thread, start by sharing this document to provide context about what needs to be done.

### How to update this document

1. Update the status as work progresses
2. Update related documents (design.md, impl.md, etc.) as needed
3. Mark the completion date when finished

The LLM should assist with implementation details and help maintain this document as work progresses.
