---
verblock: "04 Aug 2026:v0.1: matts - Initial version"
st_id: ST0011
title: "Fable review of arca_cli base code -- acceptance contract"
---

# ST0011 Fable review of arca_cli base code -- Acceptance

> Canonical acceptance contract for ST0011. Acceptance Criteria (AC) are the ratified completeness boundary; Acceptance Tests (AT) are the small red-to-green tests that prove them. Real test code lives in the suite (paths cited below); this file is the contract plus the AC-to-AT coverage map plus live status. info.md / WP info.md reference this file and never restate ACs (one home).
>
> Done = every AC is covered by a GREEN AT, or (for a non-test AC) its named evidence is satisfied, AND the AC set is the ratified full boundary. Done is read from this map, never from a hand-ticked box.
>
> Change control: clarifying an AC or AT is verifier-and-builder; shrinking scope, or weakening an AT to make it pass, needs the owner.
>
> AT status vocabulary: to-write (red-first) | red | green | n/a (non-test: doc / eyeball / gate).
>
> Non-test ACs carry their state inline -- `-- evidence: <ref> -- satisfied: yes|no` on the AC line; test-backed ACs are satisfied by a green covering AT (computed, never written). Multi-AC coverage on an AT is comma-separated.
>
> STATUS: RATIFIED (hv, 2026-08-04). AC set proposed by cc from the audit in design.md and ratified in full, together with all 7 open decisions (see tasks.md "Ratified decisions"). Scope changes from here follow the change-control note above.

## Acceptance Criteria

### ST-level

- AC-00.1 A downstream-style wrapper (Eg.Cli escript pattern) inherits correct exit codes from the dep bump alone: a failing command exits non-zero with no downstream code change

### WP-01 -- Exit codes: propagate command outcome to the OS (status: Not Started)

- AC-01.1 A failing command run via the built escript exits with status 1; a succeeding command exits 0
- AC-01.2 A command that calls `Ctx.complete(:error)` causes `run/1` to return `:error` and the escript to exit 1
- AC-01.3 `run/1` never halts the VM; `main/1` halts only for non-`:ok` outcomes
- AC-01.4 Success and failure display output is unchanged from 0.4.3 for the existing command set (regression corpus over the E-probe commands)
- AC-01.5 (non-test) Halt does not truncate piped stdout -- evidence: `cmd | cat` and `cmd > file` transcripts in impl.md -- satisfied: no

### WP-02 -- Version truth: single source and working --version (status: Not Started)

- AC-02.1 `--version` prints the name plus the exact content of the VERSION file and exits 0
- AC-02.2 `about` output contains the VERSION file content and no placeholder strings ("Arca CLI VERSION" family)

### WP-03 -- Configurator truthfulness: honour config, fail loudly (status: Not Started)

- AC-03.1 A configurator declaring `allow_unknown_args: false` and `parse_double_dash: false` reports those values from `config/0` and Optimus enforces them
- AC-03.2 A configurator whose setup raises produces a loud failure naming the configurator; the app's command set is never silently replaced by DftConfigurator's
- AC-03.3 Two configurators registering the same command name resolve to the SAME module in both parse and dispatch (last-registered wins)

### WP-04 -- Pure renderers: one style detector, correct io (status: Not Started)

- AC-04.1 A `{:spinner, label, fun}` item's fun executes exactly once per command run under each of ansi, plain, and json styles
- AC-04.2 Piped escript output contains no ANSI escape bytes; TTY output may
- AC-04.3 Piped escript output preserves UTF-8 content (emoji arrives as its UTF-8 bytes, not `\x{...}` text)
- AC-04.4 Every `Ctx.output_item` type renders under both ansi and plain (or is explicitly typed as style-specific); `{:list, items}` 2-tuple and `{:json, ...}` included

### WP-05 -- History and REPL integrity (status: Not Started)

- AC-05.1 With the History process down, History client functions return `{:error, :history_not_available, _}` instead of exiting the caller
- AC-05.2 History never exceeds the configured `history_size` (default 100)
- AC-05.3 `settings.get help_url` is recorded in REPL history; bare `history` is not
- AC-05.4 `cli.script` fails on an unknown command (no fuzzy rewrite) and stops at the first failure unless `--keep-going`

### WP-06 -- Command hygiene (status: Not Started)

- AC-06.1 `sys.cmd` passes each argument separately (`sys.cmd ls -l -a` succeeds) and prints command output exactly once
- AC-06.2 `sys.cmd` propagates the OS exit status (`sys.cmd false` exits non-zero)
- AC-06.3 `dev.info` and `dev.deps` produce truthful output in the escript: no crash, no fabricated list
- AC-06.4 `cli.debug on` persists: a subsequent separate invocation shows debug detail on errors
- AC-06.5 A `namespace_command`-generated handle returns the block value (not `[do: value]`) and the module lives under the caller's namespace
- AC-06.6 Ctx built by in-repo commands carries `command: <atom>` and a map `args`

### WP-07 -- Dead code purge and dependency prune (status: Not Started)

- AC-07.1 Grep-zero across `lib/` for: `load_config_phase`, `Multiplyer`, `err_cloc`, `REPL_MODE`, `is_repl_mode`, `OK.Pipe`; legacy command modules deleted
- AC-07.2 Pruned deps absent from mix.lock; full suite green after the prune
- AC-07.3 (non-test) Changelog maps every deleted public module/function to its replacement -- evidence: CHANGELOG.md 0.5.0 section -- satisfied: no

### WP-08 -- One error-formatting pipeline (status: Not Started)

- AC-08.1 Unknown-command, parse-error, error-tuple, and raised-exception paths all emit the single ratified dialect on their first output line
- AC-08.2 No user-visible error message renders a plain-string reason inspect-quoted (`"Key not found"` class)

### WP-09 -- Remove test-env branching from lib (status: Not Started)

- AC-09.1 `grep -r "Mix.env()" lib/` returns zero matches
- AC-09.2 `settings.all` returns real settings under test -- the fabricated test context is deleted
- AC-09.3 Full suite green with the `:test_settings` app-env mechanism removed

### WP-10 -- Docs, changelog, and 0.5.0 release (status: Not Started)

- AC-10.1 (non-test) CHANGELOG covers every WP's user-visible change with breaking flags -- evidence: CHANGELOG.md -- satisfied: no
- AC-10.2 (non-test) Exit-code contract documented in user, reference, and deployment guides -- evidence: doc diffs -- satisfied: no
- AC-10.3 (non-test) VERSION reads 0.5.0; issue 0001 closed with a Resolutions section referencing ST0011 -- evidence: `intent issues show 0001` -- satisfied: no
- AC-10.4 (non-test) E1-E8 probe set re-run post-fix with new outcomes recorded -- evidence: impl.md probe table -- satisfied: no

## Acceptance Tests

### ST-level

- AT-00.1 test/arca_cli/eg/eg_exit_code_test.exs::"eg wrapper inherits exit codes" -- covers AC-00.1 -- status: to-write (red-first)

### WP-01

- AT-01.1 test/arca_cli/exit_code_test.exs::"failing command exits 1, succeeding exits 0 (escript)" -- covers AC-01.1 -- status: to-write (red-first)
- AT-01.2 test/arca_cli/exit_code_test.exs::"Ctx.complete(:error) propagates to run/1 and exit status" -- covers AC-01.2 -- status: to-write (red-first)
- AT-01.3 test/arca_cli/run_entry_test.exs::"run/1 returns outcome without halting" -- covers AC-01.3 -- status: to-write (red-first)
- AT-01.4 test/arca_cli/display_regression_test.exs::"E-probe corpus output unchanged" -- covers AC-01.4 -- status: to-write (red-first)
- Coverage: AC-01.5 is non-test (evidence on the AC line); all other WP-01 ACs covered above

### WP-02

- AT-02.1 test/arca_cli/version_test.exs::"--version prints VERSION content" -- covers AC-02.1 -- status: to-write (red-first)
- AT-02.2 test/arca_cli/version_test.exs::"about reports real version, no placeholders" -- covers AC-02.2 -- status: to-write (red-first)
- Coverage: complete

### WP-03

- AT-03.1 test/arca_cli/configurator/truthfulness_test.exs::"explicit false survives config round-trip" -- covers AC-03.1 -- status: to-write (red-first)
- AT-03.2 test/arca_cli/configurator/truthfulness_test.exs::"broken configurator fails loudly, no silent fallback" -- covers AC-03.2 -- status: to-write (red-first)
- AT-03.3 test/arca_cli/configurator/truthfulness_test.exs::"duplicate command resolves identically in parse and dispatch" -- covers AC-03.3 -- status: to-write (red-first)
- Coverage: complete

### WP-04

- AT-04.1 test/arca_cli/output/purity_test.exs::"spinner fun runs once under every style" -- covers AC-04.1 -- status: to-write (red-first)
- AT-04.2 test/arca_cli/output/io_correctness_test.exs::"piped output has no ANSI bytes" -- covers AC-04.2 -- status: to-write (red-first)
- AT-04.3 test/arca_cli/output/io_correctness_test.exs::"piped output preserves UTF-8" -- covers AC-04.3 -- status: to-write (red-first)
- AT-04.4 test/arca_cli/output/renderer_parity_test.exs::"item-type parity across renderers" -- covers AC-04.4 -- status: to-write (red-first)
- Coverage: complete

### WP-05

- AT-05.1 test/arca_cli/history/degradation_test.exs::"History down yields error tuple, no exit" -- covers AC-05.1 -- status: to-write (red-first)
- AT-05.2 test/arca_cli/history/bounded_test.exs::"history trims at history_size" -- covers AC-05.2 -- status: to-write (red-first)
- AT-05.3 test/arca_cli/repl/should_push_test.exs::"first-token exclusion only" -- covers AC-05.3 -- status: to-write (red-first)
- AT-05.4 test/arca_cli/commands/cli_script_strict_test.exs::"script is strict and stops on first failure" -- covers AC-05.4 -- status: to-write (red-first)
- Coverage: complete

### WP-06

- AT-06.1 test/arca_cli/commands/sys_cmd_test.exs::"multi-arg passthrough, single print" -- covers AC-06.1 -- status: to-write (red-first)
- AT-06.2 test/arca_cli/commands/sys_cmd_test.exs::"OS exit status propagates" -- covers AC-06.2 -- status: to-write (red-first)
- AT-06.3 test/arca_cli/commands/dev_commands_escript_test.exs::"dev.info/dev.deps truthful in escript" -- covers AC-06.3 -- status: to-write (red-first)
- AT-06.4 test/arca_cli/commands/cli_debug_persistence_test.exs::"debug_mode survives process boundary" -- covers AC-06.4 -- status: to-write (red-first)
- AT-06.5 test/arca_cli/commands/namespace_command_helper_test.exs::"generated handle returns block value exactly" -- covers AC-06.5 -- status: to-write (red-first)
- AT-06.6 test/arca_cli/ctx_usage_test.exs::"in-repo commands build well-formed Ctx" -- covers AC-06.6 -- status: to-write (red-first)
- Coverage: complete

### WP-07

- AT-07.1 test/arca_cli/dead_code_gate_test.exs::"grep-zero for purged symbols" -- covers AC-07.1 -- status: to-write (red-first)
- AT-07.2 test/arca_cli/dead_code_gate_test.exs::"pruned deps absent from lock" -- covers AC-07.2 -- status: to-write (red-first)
- Coverage: AC-07.3 is non-test (evidence on the AC line)

### WP-08

- AT-08.1 test/arca_cli/error_format_test.exs::"one dialect across all failure paths" -- covers AC-08.1 -- status: to-write (red-first)
- AT-08.2 test/arca_cli/error_format_test.exs::"no inspect-quoted reasons" -- covers AC-08.2 -- status: to-write (red-first)
- Coverage: complete

### WP-09

- AT-09.1 test/arca_cli/no_test_env_gate_test.exs::"lib has zero Mix.env sites" -- covers AC-09.1 -- status: to-write (red-first)
- AT-09.2 test/arca_cli/commands/settings_all_real_path_test.exs::"settings.all uses the production path under test" -- covers AC-09.2 -- status: to-write (red-first)
- AT-09.3 (suite gate) full test run green post-migration -- covers AC-09.3 -- status: to-write (red-first)
- Coverage: complete

### WP-10

- Coverage: all WP-10 ACs are non-test (evidence on the AC lines); no ATs
