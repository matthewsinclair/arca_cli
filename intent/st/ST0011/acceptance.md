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
>
> Baseline clarification (vc proposed, cc concurred, 2026-08-04): AC-01.4's "unchanged from 0.4.3" is deliberately falsified later in this same thread by WP-02 (version strings), WP-04 (pipe bytes) and WP-08 (error dialect). It therefore reads as: the display corpus re-baselines at each WP whose ratified ACs change output, with the diff recorded in impl.md; AT-01.4 stays green against the current baseline rather than against 0.4.3 forever. Unexplained drift is still a regression -- this licenses only the changes some ratified AC already demands.

## Acceptance Criteria

### ST-level

- AC-00.1 A downstream-style wrapper (Eg.Cli escript pattern) inherits correct exit codes from the dep bump alone: a failing command exits non-zero with no downstream code change

### WP-01 -- Exit codes: propagate command outcome to the OS (status: Complete)

- AC-01.1 A failing command run via the built escript exits with status 1; a succeeding command exits 0
- AC-01.2 A command that calls `Ctx.complete(:error)` causes `run/1` to return `:error` and the escript to exit 1
- AC-01.3 `run/1` never halts the VM; `main/1` halts only for non-`:ok` outcomes
- AC-01.4 Success and failure display output is unchanged from 0.4.3 for the existing command set (regression corpus over the E-probe commands)
- AC-01.5 (non-test) Halt does not truncate piped stdout -- evidence: `cmd | cat` and `cmd > file` transcripts in impl.md -- satisfied: yes

### WP-02 -- Version truth: single source and working --version (status: Complete)

- AC-02.1 `--version` prints the name plus the exact content of the VERSION file and exits 0
- AC-02.2 `about` output contains the VERSION file content and no placeholder strings ("Arca CLI VERSION" family)

### WP-03 -- Configurator truthfulness: honour config, fail loudly (status: Complete)

- AC-03.1 A configurator declaring `allow_unknown_args: false` and `parse_double_dash: false` reports those values from `config/0` and Optimus enforces them
- AC-03.2 A configurator whose setup raises produces a loud failure naming the configurator; the app's command set is never silently replaced by DftConfigurator's
- AC-03.3 Two configurators registering the same command name resolve to the SAME module in both parse and dispatch (last-registered wins)

### WP-04 -- Pure renderers: one style detector, correct io (status: Complete)

- AC-04.1 A `{:spinner, label, fun}` item's fun executes exactly once per command run under each of ansi, plain, and json styles
- AC-04.2 Piped escript output contains no ANSI escape bytes; TTY output may
- AC-04.3 Piped escript output preserves UTF-8 content (emoji arrives as its UTF-8 bytes, not `\x{...}` text)
- AC-04.4 Every `Ctx.output_item` type renders under both ansi and plain (or is explicitly typed as style-specific); `{:list, items}` 2-tuple and `{:json, ...}` included

### WP-05 -- History and REPL integrity (status: Complete)

- AC-05.1 With the History process down, History client functions return `{:error, :history_not_available, _}` instead of exiting the caller
- AC-05.2 History never exceeds the configured `history_size` (default 100)
- AC-05.3 `settings.get help_url` is recorded in REPL history; bare `history` is not
- AC-05.4 `cli.script` fails on an unknown command (no fuzzy rewrite) and stops at the first failure unless `--keep-going`

### WP-06 -- Command hygiene (status: Complete)

- AC-06.1 `sys.cmd` passes each argument separately (`sys.cmd ls -l -a` succeeds) and prints command output exactly once
- AC-06.2 `sys.cmd` propagates the OS exit status (`sys.cmd false` exits non-zero)
- AC-06.3 `dev.info` and `dev.deps` produce truthful output in the escript: no crash, no fabricated list
- AC-06.4 `cli.debug on` persists: a subsequent separate invocation shows debug detail on errors
- AC-06.5 A `namespace_command`-generated handle returns the block value (not `[do: value]`) and the module lives under the caller's namespace
- AC-06.6 Ctx built by in-repo commands carries `command: <atom>` and a map `args`
- AC-06.7 No user-supplied string reaches `String.to_atom/1`: repeatedly issuing distinct unknown commands in one REPL session leaves the atom count flat (finding C11; `arca_cli.ex:468`, `help.ex:81,217`, `ctx.ex:377`)

### WP-07 -- Dead code purge and dependency prune (status: Complete)

- AC-07.1 Grep-zero across `lib/` for: `load_config_phase`, `Multiplyer`, `err_cloc`, `err_cfloc`, `REPL_MODE`, `is_repl_mode`, `OK.Pipe`; legacy command modules deleted -- satisfied: yes
- AC-07.2 Pruned deps absent from mix.lock; full suite green after the prune -- satisfied: yes, **as amended below**
- AC-07.3 (non-test) Changelog maps every deleted public module/function to its replacement -- evidence: CHANGELOG.md 0.5.0 section -- satisfied: yes

**AC-07.2 amendment (cc, 2026-08-04) -- for hv, because it changes what the AC asserts.** The AC cannot be met as literally written, and this was not knowable when it was drafted. Of the ten pruned dependencies, only three (`dotenv`, `logger_file_backend`, `logger_backends`) can leave `mix.lock`. The other seven -- `castore`, `certifi`, `elixir_uuid`, `pathex`, `table_rex`, `ucwidth`, `ok` -- are dependencies of `arca_config`, so they stay resolved no matter what this project declares. Removing them from `mix.exs` makes them arca_config's business, which is the most this repository can do about them.

The AC is therefore read as: pruned deps are absent from `mix.exs`, and absent from `mix.lock` where nothing else depends on them. Both halves are asserted by AT-07.2, and the second half names its three deps explicitly rather than hiding the limit. Flagged rather than quietly satisfied, because reading it the loose way would have let a future reader believe the lock was clean when it is not. hv can rule the remainder into the arca_config work.

### WP-08 -- One error-formatting pipeline (status: Complete)

- AC-08.1 Unknown-command, parse-error, error-tuple, and raised-exception paths all emit the single ratified dialect on their first output line
- AC-08.2 No user-visible error message renders a plain-string reason inspect-quoted (`"Key not found"` class)
- AC-08.3 A command that reports a failure exits non-zero even when it returns its message as a plain string: `settings.get nosuchkey`, `cfg.get nosuchkey` and `cli.redo 999` all exit 1 (finding A13; the `cli.script` and `sys.cmd` legs of the same defect are AC-05.4 and AC-06.2)

### WP-09 -- Remove test-env branching from lib (status: Complete)

- AC-09.1 `grep -r "Mix.env()" lib/` returns zero matches -- satisfied: yes (12 sites removed, incl. `output.ex`'s `MIX_ENV` env-var read, which the grep does not catch)
- AC-09.2 `settings.all` returns real settings under test -- the fabricated test context is deleted -- satisfied: yes (`build_test_context` deleted; proven on the escript too)
- AC-09.3 Full suite green with the `:test_settings` app-env mechanism removed -- satisfied: yes (717 green, zero `:test_settings` sites anywhere)
- AC-09.4 Every documented `expected.out` pattern in the fixture framework actually matches, and still discriminates against non-matching input (finding A14) -- satisfied: yes (fixed early, in WP-02)

### WP-10 -- Docs, changelog, and 0.5.0 release (status: Complete)

- AC-10.1 (non-test) CHANGELOG covers every WP's user-visible change with breaking flags -- evidence: CHANGELOG.md 0.5.0 section -- satisfied: yes. Three breaking areas flagged (exit codes, stdout/ANSI, removed public names), a replacement map for every removed module and function, an embedder note, and a "Known limitations" entry naming the four commands that still exit 0 on failure.
- AC-10.2 (non-test) Exit-code contract documented in user, reference, and deployment guides -- evidence: doc diffs -- satisfied: yes. User guide: the contract and a shell conditional. Reference guide: `main/1` vs `run/1`, the downstream escript pattern, and a table mapping command return values to exit statuses. Deployment guide: CI usage, stream separation, and an upgrade warning.
- AC-10.3 (non-test) VERSION reads 0.5.0; issue 0001 closed with a Resolutions section referencing ST0011 -- evidence: `intent issues show 0001` -- satisfied: yes. The Resolutions section records the one deliberate departure from the issue's proposed fix (halt in `main/1` rather than at the escript boundary, so downstream inherits the fix from a dependency bump alone) and names the four remaining A13-class instances rather than implying the class is fully closed. Its reproduction claim was re-run against the built escript: exit 1.
- AC-10.4 (non-test) E1-E8 probe set re-run post-fix with new outcomes recorded -- evidence: impl.md probe table -- satisfied: yes. All eight re-run against the built 0.5.0 escript; table in impl.md.

## Acceptance Tests

### ST-level

- AT-00.1 test/arca_cli/eg/eg_exit_code_test.exs::"downstream wrapper exit codes" (3 tests) -- covers AC-00.1 -- status: green

### WP-01

- AT-01.1 test/arca_cli/exit_code_test.exs::"failing commands" + "succeeding commands" (8 tests) -- covers AC-01.1 -- status: green
- AT-01.2 test/arca_cli/exit_code_test.exs::"context status drives exit status" (2 tests) + test/arca_cli/run_entry_test.exs::"run/1 outcome" (7 tests) -- covers AC-01.2 -- status: green
- AT-01.3 test/arca_cli/run_entry_test.exs::"invariant: a failing run leaves the VM able to run the next command" -- covers AC-01.3 -- status: green
- AT-01.4 test/arca_cli/display_regression_test.exs (6 tests) -- covers AC-01.4 -- status: green
- Coverage: AC-01.5 is non-test (evidence on the AC line); all other WP-01 ACs covered above

> AT naming note (verifier-and-builder clarification, 2026-08-04): the drafted AT names were placeholders written before the tests existed. They are restated above as the real describe blocks, one assertion focus per test per IN-EX-TEST-001. Coverage is unchanged; only the citations are now accurate.
>
> AT-01.1 runs the CLI as a real OS subprocess via `mix run -e` rather than the built escript, so the suite carries no dependency on a build artifact. The escript itself is covered by the AC-10.4 probe re-run recorded in impl.md, which is the contract's own mechanism for escript evidence.

### WP-02

- AT-02.1 test/arca_cli/version_test.exs::"--version" (2 tests) -- covers AC-02.1 -- status: green
- AT-02.2 test/arca_cli/version_test.exs::"version reporting" (4 tests) -- covers AC-02.2 -- status: green
- Coverage: complete

> The ATs read the VERSION file at runtime rather than hardcoding a number, so a release bump does not falsify them. The three pre-existing tests and one golden fixture that hardcoded `arca_cli 0.1.0` were updated the same way -- they had been asserting the defect.

### WP-03

- AT-03.1 test/arca_cli/configurator/truthfulness_test.exs::"explicit false is honoured" (4 tests) -- covers AC-03.1 -- status: green
- AT-03.2 test/arca_cli/configurator/truthfulness_test.exs::"broken configurator fails loudly" (2 tests) -- covers AC-03.2 -- status: green
- AT-03.3 test/arca_cli/configurator/truthfulness_test.exs::"duplicate command names resolve consistently" (3 tests) -- covers AC-03.3 -- status: green
- Coverage: complete

### WP-04

- AT-04.1 test/arca_cli/output/purity_test.exs (7 tests) -- covers AC-04.1 -- status: green
- AT-04.2 test/arca_cli/output/io_correctness_test.exs::"piped output carries no decoration" + "TTY detection" (3 tests) -- covers AC-04.2 -- status: green
- AT-04.3 test/arca_cli/output/io_correctness_test.exs::"piped output preserves content" (2 tests) -- covers AC-04.3 -- status: green
- AT-04.4 test/arca_cli/output/renderer_parity_test.exs (37 tests) -- covers AC-04.4 -- status: green
- Coverage: complete

### WP-05

- AT-05.1 test/arca_cli/history/degradation_test.exs (8 tests) -- covers AC-05.1 -- status: green
- AT-05.2 test/arca_cli/history/bounded_test.exs (5 tests) -- covers AC-05.2 -- status: green
- AT-05.3 test/arca_cli/repl/should_push_test.exs (8 tests) -- covers AC-05.3 -- status: green
- AT-05.4 test/arca_cli/commands/cli_script_strict_test.exs (7 tests) -- covers AC-05.4 -- status: green
- Coverage: complete

### WP-06

- AT-06.1 test/arca_cli/commands/sys_cmd_test.exs (14 tests) -- covers AC-06.1 -- status: green
- AT-06.2 test/arca_cli/commands/sys_cmd_test.exs (same file) -- covers AC-06.2 -- status: green
- AT-06.3 test/arca_cli/commands/dev_commands_escript_test.exs (9 tests) -- covers AC-06.3 -- status: green
- AT-06.4 test/arca_cli/commands/cli_debug_persistence_test.exs (9 tests) -- covers AC-06.4 -- status: green
- AT-06.5 test/arca_cli/commands/namespace_command_helper_test.exs (8 tests) -- covers AC-06.5 -- status: green
- AT-06.6 test/arca_cli/ctx_usage_test.exs (9 tests) -- covers AC-06.6 -- status: green
- AT-06.7 test/arca_cli/atom_safety_test.exs (7 tests) -- covers AC-06.7 -- status: green
- Coverage: complete. Two further WP-06 deliverables are not AC-gated but are covered:
  test/arca_cli/commands/sub_command_arg_order_test.exs (5 tests, argv declaration
  order) and test/arca_cli/utils/put_lines_test.exs (7 tests, no IO.inspect at users).
- Coverage: complete

### WP-07

- AT-07.1 test/arca_cli/dead_code_gate_test.exs, describe "purged symbols (AC-07.1)" (7 tests) -- covers AC-07.1 -- status: green. One test per purged cluster rather than one omnibus grep, so a partial revert names which cluster came back.
- AT-07.2 test/arca_cli/dead_code_gate_test.exs, describe "dependency prune (AC-07.2)" (2 tests) -- covers AC-07.2 -- status: green. Split in two because the AC is: absent from `mix.exs` (all ten), and absent from `mix.lock` (only the three with no other dependant). See the AC-07.2 amendment above.
- AT-07.3 test/arca_cli/dead_code_gate_test.exs::"invariant: the scanner finds strings that are genuinely present" -- covers the gate itself -- status: green. Without it, a scanner that silently matched nothing would report every invariant above as satisfied.
- Coverage: AC-07.3 is non-test (evidence on the AC line)

### WP-08

- AT-08.1 test/arca_cli/error_format_test.exs (24 tests) -- covers AC-08.1 -- status: green
- AT-08.2 test/arca_cli/error_format_test.exs (same file, "reasons are text" describe) -- covers AC-08.2 -- status: green
- AT-08.3 test/arca_cli/exit_code_test.exs (18 tests, "commands that report failure as a plain string" describe) -- covers AC-08.3 -- status: green
- Coverage: complete. The dialect assertions cover the four AC-08.1 paths plus
  setting-lookup and redo; the suggestion and namespace blocks are asserted to
  survive the change, and the debug block to remain appended below the dialect line.

### WP-09

- AT-09.1 test/arca_cli/no_test_env_gate_test.exs (4 tests) -- covers AC-09.1 -- status: green. Proven to discriminate: a temporary `Mix.env()` added to `output.ex` turned it red naming `lib/arca_cli/output.ex:217`, and removing it turned it green. Carries its own control test, so a scanner that silently matched nothing could not report the invariant as satisfied.
- AT-09.2 test/arca_cli/cli/arca_cli_test.exs::"settings.all reports the settings actually in force" -- covers AC-09.2 -- status: green. Written in place of the planned new file: the existing test was the defect, accepting any of three outputs including the fabricated one, so replacing it removes the false green rather than leaving it beside a new test.
- AT-09.3 test/arca_cli/no_test_env_gate_test.exs::"invariant: settings come from configuration, not from application env" -- covers AC-09.3 -- status: green. The AC has two halves and they need different kinds of evidence: that the mechanism is gone is a property of the source, asserted by this test; that the suite is green without it is the run itself -- 717 green, 10 consecutive runs (6 piped, 4 pty).
- AT-09.4 test/arca_cli/testing/cli_fixtures_pattern_test.exs (9 tests) -- covers AC-09.4 -- status: green (fixed early, in WP-02, because it blocked the version fixture)
- Coverage: complete

### WP-10

- Coverage: all WP-10 ACs are non-test (evidence on the AC lines); no ATs
