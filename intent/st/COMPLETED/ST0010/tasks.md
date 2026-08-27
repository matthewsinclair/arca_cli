# Tasks - ST0010: HEREDOC injection for cli.script

## Status: ALL TASKS COMPLETE

All tasks have been completed and moved to `done.md`.
See `done.md` for detailed completion information.

Completion date: 2025-10-29
Time taken: ~3-4 hours (under the 9-14 hour estimate)
Final test results: 456 tests passing, 0 failures, 0 warnings

---

## Original Task Plan

### Phase 1: Core Implementation

- [ ] **T1: Create InputProvider GenServer**
  - Location: `lib/arca_cli/commands/input_provider.ex`
  - Implement IO protocol (`handle_info({:io_request, ...})`)
  - Handle `{:get_line, prompt}` requests
  - Handle `{:get_chars, prompt, count}` requests
  - Return `:eof` when lines exhausted
  - Add @moduledoc with usage examples

- [ ] **T2: Add heredoc parser to cli_script_command.ex**
  - Create `parse_script_commands/1` function
  - Implement `parse_lines/4` with state machine
  - States: `:normal` and `{:in_heredoc, cmd, marker, lines, start_line}`
  - Regex for detecting heredoc start: `~r/^(.+?)\s+<<(\w+)$/`
  - Return `{:ok, commands}` or `{:error, message}`
  - Preserve line numbers for error reporting

- [ ] **T3: Update command execution in cli_script_command.ex**
  - Modify `process_script_commands/3` to call parser
  - Create `execute_command/3` pattern matching:
    - `{:command, cmd}` → existing behavior
    - `{:command_with_stdin, cmd, lines}` → new behavior with group leader swap
  - Implement group leader redirection:
    - Start InputProvider
    - Save original `Process.group_leader()`
    - Set provider as group leader
    - Execute command
    - Restore original group leader
    - Stop InputProvider
  - Add error handling for group leader swap failures

- [ ] **T4: Error handling and reporting**
  - Handle unclosed heredoc error from parser
  - Format error message with line numbers
  - Exit with appropriate exit code
  - Add logging for debugging (optional)

### Phase 2: Testing

- [ ] **T5: Unit tests for InputProvider**
  - File: `test/arca_cli/commands/input_provider_test.exs`
  - Test serving lines via `IO.gets/1`
  - Test returning `:eof` when exhausted
  - Test `IO.getn/2` character reading
  - Test empty stdin list
  - Test multiple consumers (if relevant)

- [ ] **T6: Parser unit tests**
  - File: `test/arca_cli/commands/cli_script_command_test.exs`
  - Test simple heredoc parsing
  - Test multiple heredocs in one script
  - Test mixed regular commands and heredocs
  - Test unclosed heredoc error detection (with line numbers)
  - Test whitespace preservation
  - Test various marker names (`EOF`, `END`, `INPUT123`)
  - Test Windows line endings (`\r\n`)
  - Test empty heredoc (no lines between markers)
  - Test heredoc with only whitespace

- [ ] **T7: Integration tests**
  - Create mock command that reads stdin and echoes it
  - Test heredoc injection with mock command
  - Test backward compatibility (existing .cli files still work)
  - Test error scenarios (unclosed heredoc, etc.)
  - Test edge cases (long heredoc, unicode content)

- [ ] **T8: Real-world command testing (optional)**
  - Test with `ll.llm.chat` if available
  - Test with `ll.play` if available
  - Test with `ll.agent.engage` if available
  - Verify behavior matches expectations

### Phase 3: Documentation

- [ ] **T9: Add heredoc examples to test fixtures**
  - Create `test/fixtures/scripts/test_heredoc.cli`
  - Include examples of each use case
  - Document expected behavior in comments

- [ ] **T10: Update cli.script help text**
  - File: `lib/arca_cli/commands/cli_script_command.ex`
  - Add heredoc syntax to command description
  - Add example to help output

- [ ] **T11: Update user documentation (if exists)**
  - Document heredoc syntax in user-facing docs
  - Add examples of common use cases
  - Document known limitations
  - Add troubleshooting section

### Phase 4: Polish

- [ ] **T12: Code review and cleanup**
  - Review all changes for consistency
  - Add missing specs (@spec annotations)
  - Ensure consistent naming
  - Check for edge cases in error handling

- [ ] **T13: Performance testing**
  - Test with large heredocs (1000+ lines)
  - Test with many heredocs in one script
  - Verify no memory leaks
  - Profile if needed

- [ ] **T14: Final testing**
  - Run full test suite
  - Test on different platforms (if applicable)
  - Verify backward compatibility
  - Test error messages are clear and helpful

## Task Notes

### T1 Notes: InputProvider Implementation

The InputProvider must implement the Erlang IO protocol correctly. Key points:

- Must handle `:io_request` messages synchronously
- Must reply with `:io_reply` messages
- State should be `{lines_list, current_index}`
- Use `Enum.at/2` for O(n) access (acceptable for typical heredoc sizes)

Reference: `ExUnit.CaptureIO` source code for similar implementation

### T2 Notes: Parser State Machine

The parser should be tail-recursive to handle large .cli files efficiently. Key considerations:

- Preserve whitespace in heredoc content (don't trim except for marker detection)
- Track line numbers for error reporting
- Use `String.trim/1` only for detecting comments and markers
- Heredoc regex must require space before `<<` to avoid false positives

### T3 Notes: Group Leader Swap

Important: Always restore the original group leader, even if command execution fails. Use a `try...after` block:

```elixir
try do
  Process.group_leader(self(), provider)
  Repl.eval_for_redo({0, cmd_string}, settings, optimus)
after
  Process.group_leader(self(), original_leader)
  GenServer.stop(provider)
end
```

### T6 Notes: Parser Tests

Critical edge cases to test:

1. Heredoc marker appears in content (should terminate early - document as limitation)
2. Command with `<<` but not heredoc (e.g., `echo "<<foo"`)
3. Marker with leading/trailing whitespace
4. Mixed line endings in single file
5. Unicode markers (should they work?)

### T8 Notes: Real Command Testing

If real interactive commands aren't available in the test environment, create a minimal mock command that:

- Calls `IO.gets/1` multiple times
- Returns what it read
- Exits on specific input (e.g., "/exit")

This can be a simple command in the test suite itself.

## Dependencies

### Sequential Dependencies

Must be completed in order:

1. **T1** (InputProvider) must complete before **T3** (execution wrapper)
2. **T2** (parser) must complete before **T3** (execution wrapper)
3. **T1, T2, T3** must complete before **T5, T6, T7** (testing)
4. **T5, T6, T7** should complete before **T12** (code review)

### Parallel Opportunities

Can be worked on in parallel:

- **T1** and **T2** (independent implementations)
- **T5** and **T6** (independent test suites)
- **T9**, **T10**, **T11** (documentation tasks)

### External Dependencies

None identified. All dependencies are within the Arca.Cli codebase.

## Estimation

Based on the design:

- Core implementation (T1-T4): ~4-6 hours
- Testing (T5-T8): ~3-4 hours
- Documentation (T9-T11): ~1-2 hours
- Polish (T12-T14): ~1-2 hours

**Total estimated effort**: 9-14 hours

This assumes familiarity with:

- Elixir GenServer patterns
- Erlang IO protocol
- The existing Arca.Cli codebase

## Definition of Done

This steel thread is complete when:

- [ ] All tasks marked complete
- [ ] All tests passing
- [ ] No regressions in existing .cli file behavior
- [ ] Documentation updated
- [ ] Code reviewed and approved
- [ ] Can successfully script an interactive command using heredoc syntax
- [ ] Success criteria from info.md satisfied
