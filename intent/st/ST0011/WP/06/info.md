---
verblock: "04 Aug 2026:v0.1: matts - Initial version"
wp_id: WP-06
title: "Command hygiene: Ctx API, sys.cmd, dev.*, cli.debug, namespace helper"
scope: Small
status: Not Started
---

# WP-06: Command hygiene: Ctx API, sys.cmd, dev.*, cli.debug, namespace helper

## Objective

The shipped commands and command-building helpers must do what they claim in every deployment format. Findings: A8, A9, A10, A11, C1, C4, C12.

## Deliverables

- Ctx API: fix the three in-repo misusers (`settings.all`, `cli.history`, `sys.info`) to `Ctx.new(args, settings, command: :"...")`; consider `Ctx.for_command(cmd, args, settings)` convenience so the right call is the easy call; guard `Ctx.new` against atom args.
- `sys.cmd` rewrite: pass unknown args as SEPARATE arguments (no joining); print once (no tuple leak -- return a Ctx or string, drop the in-handler `print_ansi` side effect); surface the OS exit status via WP-01 plumbing (`sys.cmd false` -> CLI exit non-zero, message names the OS status). Delete the copy-paste `SysCommand` twin (WP-07 dependency noted).
- `dev.info`: escript-safe -- report from `Application.spec` / `System` info, no `Mix.env()` at runtime; never crashes in escript.
- `dev.deps`: report the REAL loaded applications (`Application.loaded_applications/0`) or say "unavailable in this deployment"; delete the fabricated hardcoded list.
- `cli.debug`: make persistence real -- load persisted `debug_mode` into app env at startup (delayed-init or first-read); or drop persistence and document it as session-only. Recommended: load at startup.
- `namespace_command` macro: unwrap the `do:` block correctly (generated `handle/3` returns the block's value, not `[do: value]`); generate modules under the CALLER's namespace, not `Arca.Cli.Commands.*`; strengthen the helper tests to assert exact output (the `=~` assertions masked the wrapper).
- `BaseSubCommand.extract_arguments`: derive argv from the command's declared arg order, not `Map.values/1` term order; fix the moduledoc (`@sub_commands` attribute style is dead -- config key is the mechanism).
- `put_lines(map/tuple)`: stop `IO.inspect`-ing at users; render via one explicit path.

## Acceptance

Acceptance Criteria for this work package live in the steel thread's `acceptance.md`, under the `WP-06` heading (single source of truth). Do not restate ACs here.

## Dependencies

- WP-01 (sys.cmd exit-status leg).
