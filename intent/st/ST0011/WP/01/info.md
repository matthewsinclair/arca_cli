---
verblock: "04 Aug 2026:v0.1: matts - Initial version"
wp_id: WP-01
title: "Exit codes: propagate command outcome to the OS"
scope: Small
status: Not Started
---

# WP-01: Exit codes: propagate command outcome to the OS

## Objective

Close issue 0001: a failed command must exit non-zero. Carry the command outcome from handler to OS boundary without changing any display behaviour. Findings: A1, plus the script/sys.cmd outcome legs of A7/A10 land in their own WPs.

## Deliverables

- Status-carrying dispatch: `process_command_result(%Ctx{})` folds `ctx.status` into the result (making `Ctx.complete/2` load-bearing); `execute_command/5` and a new `dispatch/3` carry `{status, output}`.
- Legacy adapters: `handle_args/3`, `handle_subcommand/4`, `parse_command_line/3` keep their current string-returning contracts as one-line wrappers over the status-carrying path (REPL and downstream callers unchanged).
- `Arca.Cli.run/1`: pure entry point -- parses, prints exactly as today, returns `:ok | :error | :warning`. Never halts.
- `Arca.Cli.main/1`: thin boundary -- `argv |> run() |> halt_for()`. `System.halt(1)` on `:error`; `:warning` exits 0 (hv ruling 2026-08-04 pending confirmation).
- Delete the dead error branches in `main/1` (`arca_cli.ex:294-311`).
- Migrate the ~20 in-repo test call sites from `main/1` to `run/1`.
- Regression tests assert the REAL process exit code (`System.cmd` against the built escript and `mix arca_cli`), not the return value.
- Verify piped stdout is not truncated by the halt (`cmd | cat`, `cmd > file`); use flush-safe halt semantics if it is.

## Acceptance

Acceptance Criteria for this work package live in the steel thread's `acceptance.md`, under the `WP-01` heading (single source of truth). Do not restate ACs here.

## Dependencies

- None. This WP goes first; several later WPs build on `{status, output}` plumbing.
- Decision needed from hv: `:warning` exit code (recommended 0); single exit code 1 for all failures vs differentiated codes (recommended: single 1).
