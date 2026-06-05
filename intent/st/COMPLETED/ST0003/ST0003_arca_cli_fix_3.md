---
verblock: "20 Mar 2025:v0.1: Matthew Sinclair - Updated via STP upgrade"
stp_version: 1.0.0
status: Not Started
created: 20250320
completed:
---

# Arca.Cli Help System Fix - Part 3

## Problem Description

After implementing the initial fixes for help display in the Multiplyer CLI, we've identified a deeper issue that requires changes to Arca.Cli's core functionality.

The current problem is:

- Running a command with no arguments (`scripts/cli command`) should display help text
- However, this only works for some commands (`eg.progress`) but not others (`sia.list`, `cfg.paths`, etc.)
- The help is correctly shown when using explicit help commands (`scripts/cli help command`) or flags (`scripts/cli command --help`)

## Technical Analysis

1. The issue appears to be in the pattern matching and help tuple handling within Arca.Cli's command processing pipeline.

2. Many type violation warnings appear in all commands using the CommandBase macro:

   ```
   warning: the following clause will never match:
        :help
   because it attempts to match on the result of:
        result
   which has type:
        dynamic(%{..., metadata: term()})
   ```

3. Similar warnings appear for `{:help, subcmd}` pattern matching.

4. The current flow for help processing in Arca.Cli seems inconsistent:
   - How `help command` is processed
   - How `command --help` is processed
   - How `command` with no args is processed when it should display help

## Proposed Solution

The Arca.Cli library needs to standardize how it detects and handles "show help" scenarios:

1. Modify `Arca.Cli.handle_command/5` to detect when a command is run with no arguments and consistently handle it as a help request

2. Standardize the help tuple format and ensure it's properly transformed into formatted help text at all points in the command processing pipeline

3. Ensure the `Arca.Cli.REPL` module properly handles help requests when they bubble up from command execution

4. Add a consistent mechanism to detect "show help" conditions before command execution

5. Ensure help text output bypasses any formatter callbacks that might interfere with proper display

## Implementation Guidelines

1. Review the `Arca.Cli.handle_command_help/2` function and ensure it's consistently used

2. Examine the return values from `Optimus.parse/2` to properly detect empty/help arguments

3. Add a pre-execution check in `Arca.Cli.handle_command/5` for empty argument conditions

4. Ensure command registration in `Arca.Cli.register_command/3` properly sets up help handling

5. Make the REPL execution flow consistent with the direct CLI execution flow for help handling

## Implementation Details

The following changes were made to fix the help system:

1. Added an opt-in `show_help_on_empty` configuration option to command definitions, allowing commands to specify whether they should show help when run with no arguments

2. Added `should_show_help_for_command?` function in Arca.Cli to determine if help should be shown based on both the command configuration and argument state

3. Fixed type violations in BaseCommand for `:help` and `{:help, subcmd}` patterns by adding explicit function heads with proper type specifications

4. Modified REPL's print function to consistently handle help text by bypassing formatter callbacks for both help tuples and help text output

5. Added helper function `is_help_text?` to consistently detect help text across the codebase

These changes allow commands to opt into showing help when run with no arguments without disrupting existing behavior for commands that already handle empty arguments properly.

## Integration with Client Applications

After these changes, client applications like Multiplyer should be able to remove their workarounds for help handling. Specifically:

1. The need for special pattern matching on `{:help, subcmd}` tuples in the formatter callbacks
2. Direct calls to `IO.puts` to display help text
3. Custom pattern matching in command handling to detect help conditions

The goal is to make help display work consistently through the standard Arca.Cli interfaces regardless of how help is requested.
