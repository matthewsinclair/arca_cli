---
st_id: ST0011
title: Fable review of arca_cli base code
---

# ST0011: Fable review of arca_cli base code -- Acceptance

> **THIS FILE IS A GENERATED VIEW, AND A ROW AUTHORED HERE IS DISCARDED BY THE NEXT SYNC.** The acceptance contract is canon in the thread model; this file renders it. Acceptance Criteria (AC) are the ratified completeness boundary; Acceptance Tests (AT) are the small red-to-green tests that prove them.
>
> Done = every AC is covered by a GREEN AT, or (for a non-test AC) its named evidence is satisfied, AND the AC set is the ratified full boundary. Done is read from this map, never from a hand-ticked box.
>
> Test-backed satisfaction is COMPUTED from covering green ATs and never stored -- storing it would be double truth. An AC has four states, not two: beyond satisfied and unsatisfied, a requirement can be **descoped** to a named thread or **withdrawn** with its reason on the record. Both are non-blocking and both are reported separately, so a thread that descoped half its contract looks like one.

## Acceptance Criteria

### ST-level

- AC-00.1 A downstream-style wrapper (Eg.Cli escript pattern) inherits correct exit codes from the dep bump alone: a failing command exits non-zero with no downstream code change -- satisfied: yes (computed)

### WP-01 -- Exit codes: propagate command outcome to the OS (status: Done)

- AC-01.1 A failing command run via the built escript exits with status 1; a succeeding command exits 0 -- satisfied: yes (computed)
- AC-01.2 A command that calls `Ctx.complete(:error)` causes `run/1` to return `:error` and the escript to exit 1 -- satisfied: yes (computed)
- AC-01.3 `run/1` never halts the VM; `main/1` halts only for non-`:ok` outcomes -- satisfied: yes (computed)
- AC-01.4 Success and failure display output is unchanged from 0.4.3 for the existing command set (regression corpus over the E-probe commands) -- satisfied: yes (computed)
- AC-01.5 (non-test) Halt does not truncate piped stdout -- evidence: `cmd | cat` and `cmd > file` transcripts in impl.md -- satisfied: yes

### WP-02 -- Version truth: single source and working --version (status: Done)

- AC-02.1 `--version` prints the name plus the exact content of the VERSION file and exits 0 -- satisfied: yes (computed)
- AC-02.2 `about` output contains the VERSION file content and no placeholder strings ("Arca CLI VERSION" family) -- satisfied: yes (computed)

### WP-03 -- Configurator truthfulness: honour config, fail loudly (status: Done)

- AC-03.1 A configurator declaring `allow_unknown_args: false` and `parse_double_dash: false` reports those values from `config/0` and Optimus enforces them -- satisfied: yes (computed)
- AC-03.2 A configurator whose setup raises produces a loud failure naming the configurator; the app's command set is never silently replaced by DftConfigurator's -- satisfied: yes (computed)
- AC-03.3 Two configurators registering the same command name resolve to the SAME module in both parse and dispatch (last-registered wins) -- satisfied: yes (computed)

### WP-04 -- Pure renderers: one style detector, correct io (status: Done)

- AC-04.1 A `{:spinner, label, fun}` item's fun executes exactly once per command run under each of ansi, plain, and json styles -- satisfied: yes (computed)
- AC-04.2 Piped escript output contains no ANSI escape bytes; TTY output may -- satisfied: yes (computed)
- AC-04.3 Piped escript output preserves UTF-8 content (emoji arrives as its UTF-8 bytes, not `\x{...}` text) -- satisfied: yes (computed)
- AC-04.4 Every `Ctx.output_item` type renders under both ansi and plain (or is explicitly typed as style-specific); `{:list, items}` 2-tuple and `{:json, ...}` included -- satisfied: yes (computed)

### WP-05 -- History and REPL integrity (status: Done)

- AC-05.1 With the History process down, History client functions return `{:error, :history_not_available, _}` instead of exiting the caller -- satisfied: yes (computed)
- AC-05.2 History never exceeds the configured `history_size` (default 100) -- satisfied: yes (computed)
- AC-05.3 `settings.get help_url` is recorded in REPL history; bare `history` is not -- satisfied: yes (computed)
- AC-05.4 `cli.script` fails on an unknown command (no fuzzy rewrite) and stops at the first failure unless `--keep-going` -- satisfied: yes (computed)

### WP-06 -- Command hygiene: Ctx API, sys.cmd, dev.*, cli.debug, namespace helper (status: Done)

- AC-06.1 `sys.cmd` passes each argument separately (`sys.cmd ls -l -a` succeeds) and prints command output exactly once -- satisfied: yes (computed)
- AC-06.2 `sys.cmd` propagates the OS exit status (`sys.cmd false` exits non-zero) -- satisfied: yes (computed)
- AC-06.3 `dev.info` and `dev.deps` produce truthful output in the escript: no crash, no fabricated list -- satisfied: yes (computed)
- AC-06.4 `cli.debug on` persists: a subsequent separate invocation shows debug detail on errors -- satisfied: yes (computed)
- AC-06.5 A `namespace_command`-generated handle returns the block value (not `[do: value]`) and the module lives under the caller's namespace -- satisfied: yes (computed)
- AC-06.6 Ctx built by in-repo commands carries `command: <atom>` and a map `args` -- satisfied: yes (computed)
- AC-06.7 No user-supplied string reaches `String.to_atom/1`: repeatedly issuing distinct unknown commands in one REPL session leaves the atom count flat (finding C11; `arca_cli.ex:468`, `help.ex:81,217`, `ctx.ex:377`) -- satisfied: yes (computed)

### WP-07 -- Dead code purge and dependency prune (status: Done)

- AC-07.1 Grep-zero across `lib/` for: `load_config_phase`, `Multiplyer`, `err_cloc`, `err_cfloc`, `REPL_MODE`, `is_repl_mode`, `OK.Pipe`; legacy command modules deleted -- satisfied: no (computed)
- AC-07.2 Pruned deps absent from mix.lock; full suite green after the prune -- satisfied: no (computed)
- AC-07.3 (non-test) Changelog maps every deleted public module/function to its replacement -- evidence: CHANGELOG.md 0.5.0 section -- satisfied: yes

### WP-08 -- One error-formatting pipeline (status: Done)

- AC-08.1 Unknown-command, parse-error, error-tuple, and raised-exception paths all emit the single ratified dialect on their first output line -- satisfied: yes (computed)
- AC-08.2 No user-visible error message renders a plain-string reason inspect-quoted (`"Key not found"` class) -- satisfied: yes (computed)
- AC-08.3 A command that reports a failure exits non-zero even when it returns its message as a plain string: `settings.get nosuchkey`, `cfg.get nosuchkey` and `cli.redo 999` all exit 1 (finding A13; the `cli.script` and `sys.cmd` legs of the same defect are AC-05.4 and AC-06.2) -- satisfied: yes (computed)

### WP-09 -- Remove test-env branching from lib (status: Done)

- AC-09.1 `grep -r "Mix.env()" lib/` returns zero matches -- satisfied: no (computed)
- AC-09.2 `settings.all` returns real settings under test -- the fabricated test context is deleted -- satisfied: no (computed)
- AC-09.3 Full suite green with the `:test_settings` app-env mechanism removed -- satisfied: no (computed)
- AC-09.4 Every documented `expected.out` pattern in the fixture framework actually matches, and still discriminates against non-matching input (finding A14) -- satisfied: yes (computed)

### WP-11 -- Closing batch: A13 residue, renderer dialect, width pins, changelog gap (status: Done)

- AC-11.1 (test) The last four A13-class paths return failure through the outcome channel rather than as display text, **and each of those failure branches is reachable** -- `sys.flush` (A24), `cfg.list` (A19), `Arca.Cli.Command.BaseSubCommand` (A18) and `Arca.Cli.Configurator.Coordinator` (A20, both `inject_subcommands/2` and the silently-skipped command in `update_command_names/3`) -- satisfied: no (computed)
- AC-11.2 (test) A context that reports failure through **either** of its two channels -- `Ctx.add_error/2` or an `{:error, message}` output item -- emits a line matching `^error:` in the form `error: <command>: <message>` under both text styles, alongside the existing `✗` block; `:json` stays structured and unchanged -- satisfied: no (computed)
- AC-11.3 (test) Renderer tests do not depend on the width of the terminal that launched them -- satisfied: no (computed)

### WP-12 -- One predicate for Ctx failure (status: Done)

- AC-12.1 (test) Exactly one authority decides whether a context failed: `Arca.Cli.Ctx.outcome/1`, with `Ctx.failed?/1` as its boolean reduction. The OS exit status, the `error:` dialect line in both text renderers, and the JSON status field all derive from it, and no site reimplements the rule -- satisfied: no (computed)
- AC-12.2 (test) In both text styles, a line matching `^error:` appears **if and only if** the context failed, across every combination of failure channel and completion state; the `✗` marker renders unconditionally, so gating the dialect line can never swallow a recorded error -- satisfied: no (computed)
- AC-12.3 (test) The JSON status field is present for every context and equals `Ctx.outcome/1`, so a machine consumer and the exit status can never disagree -- satisfied: no (computed)

### WP-13 -- Config load diagnosis survives to the user (status: Done)

- AC-13.1 (test) When configuration cannot be loaded, the `error:` line names why, and both commands that read settings give the same reason for the same failure -- satisfied: no (computed)
- AC-13.2 (test) No exception struct reaches user-facing output on a configuration failure -- satisfied: no (computed)

### WP-14 -- Pin the arca_config contract (status: Done)

- AC-14.1 (test) The arca_config surface arca_cli depends on is stated in one place and asserted, so a dependency bump that removes or renames any of it fails a test rather than a user's command -- satisfied: no (computed)
- AC-14.2 (test) The liveness probe in `config_available?/0` is pinned, and the pin is checked against what the probe actually names -- satisfied: no (computed)

### WP-15 -- Absorb the arca_config 0.3.0 error contract (status: Done)

- AC-15.1 (test) No arca_config error term reaches user-facing output as an Elixir value; every one is rendered as a sentence -- satisfied: no (computed)
- AC-15.2 (test) A fresh install with no configuration file runs silently and successfully; only a configuration that exists and cannot be read fails -- satisfied: no (computed)
- AC-15.3 (test) A failure states its reason once -- satisfied: no (computed)

## Acceptance Tests

### ST-level

- AT-00.1 (legacy) test/arca_cli/eg/eg_exit_code_test.exs::"downstream wrapper exit codes" (3 tests) -- covers AC-00.1 -- status: green

### WP-01 -- Exit codes: propagate command outcome to the OS (status: Done)

- AT-01.1 (legacy) test/arca_cli/exit_code_test.exs::"failing commands" + "succeeding commands" (8 tests) -- covers AC-01.1 -- status: green
- AT-01.2 (legacy) test/arca_cli/exit_code_test.exs::"context status drives exit status" (2 tests) + test/arca_cli/run_entry_test.exs::"run/1 outcome" (7 tests) -- covers AC-01.2 -- status: green
- AT-01.3 (legacy) test/arca_cli/run_entry_test.exs::"invariant: a failing run leaves the VM able to run the next command" -- covers AC-01.3 -- status: green
- AT-01.4 `test/arca_cli/display_regression_test.exs` -- covers AC-01.4 -- status: green -- (6 tests)

### WP-02 -- Version truth: single source and working --version (status: Done)

- AT-02.1 (legacy) test/arca_cli/version_test.exs::"--version" (2 tests) -- covers AC-02.1 -- status: green
- AT-02.2 (legacy) test/arca_cli/version_test.exs::"version reporting" (4 tests) -- covers AC-02.2 -- status: green

### WP-03 -- Configurator truthfulness: honour config, fail loudly (status: Done)

- AT-03.1 (legacy) test/arca_cli/configurator/truthfulness_test.exs::"explicit false is honoured" (4 tests) -- covers AC-03.1 -- status: green
- AT-03.2 (legacy) test/arca_cli/configurator/truthfulness_test.exs::"broken configurator fails loudly" (2 tests) -- covers AC-03.2 -- status: green
- AT-03.3 (legacy) test/arca_cli/configurator/truthfulness_test.exs::"duplicate command names resolve consistently" (3 tests) -- covers AC-03.3 -- status: green

### WP-04 -- Pure renderers: one style detector, correct io (status: Done)

- AT-04.1 `test/arca_cli/output/purity_test.exs` -- covers AC-04.1 -- status: green -- (7 tests)
- AT-04.2 (legacy) test/arca_cli/output/io_correctness_test.exs::"piped output carries no decoration" + "TTY detection" (3 tests) -- covers AC-04.2 -- status: green
- AT-04.3 (legacy) test/arca_cli/output/io_correctness_test.exs::"piped output preserves content" (2 tests) -- covers AC-04.3 -- status: green
- AT-04.4 `test/arca_cli/output/renderer_parity_test.exs` -- covers AC-04.4 -- status: green -- (37 tests)

### WP-05 -- History and REPL integrity (status: Done)

- AT-05.1 `test/arca_cli/history/degradation_test.exs` -- covers AC-05.1 -- status: green -- (8 tests)
- AT-05.2 `test/arca_cli/history/bounded_test.exs` -- covers AC-05.2 -- status: green -- (5 tests)
- AT-05.3 `test/arca_cli/repl/should_push_test.exs` -- covers AC-05.3 -- status: green -- (8 tests)
- AT-05.4 `test/arca_cli/commands/cli_script_strict_test.exs` -- covers AC-05.4 -- status: green -- (7 tests)

### WP-06 -- Command hygiene: Ctx API, sys.cmd, dev.*, cli.debug, namespace helper (status: Done)

- AT-06.1 `test/arca_cli/commands/sys_cmd_test.exs` -- covers AC-06.1 -- status: green -- (14 tests)
- AT-06.2 `test/arca_cli/commands/sys_cmd_test.exs` -- covers AC-06.2 -- status: green -- (same file)
- AT-06.3 `test/arca_cli/commands/dev_commands_escript_test.exs` -- covers AC-06.3 -- status: green -- (9 tests)
- AT-06.4 `test/arca_cli/commands/cli_debug_persistence_test.exs` -- covers AC-06.4 -- status: green -- (9 tests)
- AT-06.5 `test/arca_cli/commands/namespace_command_helper_test.exs` -- covers AC-06.5 -- status: green -- (8 tests)
- AT-06.6 `test/arca_cli/ctx_usage_test.exs` -- covers AC-06.6 -- status: green -- (9 tests)
- AT-06.7 `test/arca_cli/atom_safety_test.exs` -- covers AC-06.7 -- status: green -- (7 tests)

### WP-07 -- Dead code purge and dependency prune (status: Done)

_(no tests in this group)_

### WP-08 -- One error-formatting pipeline (status: Done)

- AT-08.1 `test/arca_cli/error_format_test.exs` -- covers AC-08.1 -- status: green -- (24 tests)
- AT-08.2 `test/arca_cli/error_format_test.exs` -- covers AC-08.2 -- status: green -- (same file, "reasons are text" describe)
- AT-08.3 `test/arca_cli/exit_code_test.exs` -- covers AC-08.3 -- status: green -- (18 tests, "commands that report failure as a plain string" describe)

### WP-09 -- Remove test-env branching from lib (status: Done)

- AT-09.4 `test/arca_cli/testing/cli_fixtures_pattern_test.exs` -- covers AC-09.4 -- status: green -- fixed early, in WP-02, because it blocked the version fixture -- (9 tests)

### WP-11 -- Closing batch: A13 residue, renderer dialect, width pins, changelog gap (status: Done)

_(no tests in this group)_

### WP-12 -- One predicate for Ctx failure (status: Done)

_(no tests in this group)_

### WP-13 -- Config load diagnosis survives to the user (status: Done)

_(no tests in this group)_

### WP-14 -- Pin the arca_config contract (status: Done)

_(no tests in this group)_

### WP-15 -- Absorb the arca_config 0.3.0 error contract (status: Done)

_(no tests in this group)_

---

_Generated by Intent v3.0.0 from `thread.json`. Do not edit this file -- it is rendered from the model, and `intent doctor` reports any hand-edit as skew._
