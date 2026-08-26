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

- AC-07.1 Grep-zero across `lib/` for: `load_config_phase`, `Multiplyer`, `err_cloc`, `err_cfloc`, `REPL_MODE`, `is_repl_mode`, `OK.Pipe`; legacy command modules deleted -- satisfied: yes (computed)
- AC-07.2 Pruned deps absent from mix.lock; full suite green after the prune -- satisfied: yes (computed)
- AC-07.3 (non-test) Changelog maps every deleted public module/function to its replacement -- evidence: CHANGELOG.md 0.5.0 section -- satisfied: yes

### WP-08 -- One error-formatting pipeline (status: Done)

- AC-08.1 Unknown-command, parse-error, error-tuple, and raised-exception paths all emit the single ratified dialect on their first output line -- satisfied: yes (computed)
- AC-08.2 No user-visible error message renders a plain-string reason inspect-quoted (`"Key not found"` class) -- satisfied: yes (computed)
- AC-08.3 A command that reports a failure exits non-zero even when it returns its message as a plain string: `settings.get nosuchkey`, `cfg.get nosuchkey` and `cli.redo 999` all exit 1 (finding A13; the `cli.script` and `sys.cmd` legs of the same defect are AC-05.4 and AC-06.2) -- satisfied: yes (computed)

### WP-09 -- Remove test-env branching from lib (status: Done)

- AC-09.1 `grep -r "Mix.env()" lib/` returns zero matches -- satisfied: yes (computed)
- AC-09.2 `settings.all` returns real settings under test -- the fabricated test context is deleted -- satisfied: yes (computed)
- AC-09.3 Full suite green with the `:test_settings` app-env mechanism removed -- satisfied: yes (computed)
- AC-09.4 Every documented `expected.out` pattern in the fixture framework actually matches, and still discriminates against non-matching input (finding A14) -- satisfied: yes (computed)

### WP-10 -- Docs, changelog, and 0.5.0 release (status: Done)

- AC-10.1 (non-test) CHANGELOG covers every WP's user-visible change with breaking flags -- evidence: CHANGELOG.md 0.5.0 section (Three breaking areas flagged (exit codes, stdout/ANSI, removed public names), a replacement map for every removed module and function, an embedder note, and a "Known limitations" entry naming the four commands that still exit 0 on failure.) -- satisfied: yes
- AC-10.2 (non-test) Exit-code contract documented in user, reference, and deployment guides -- evidence: doc diffs (User guide: the contract and a shell conditional. Reference guide: `main/1` vs `run/1`, the downstream escript pattern, and a table mapping command return values to exit statuses. Deployment guide: CI usage, stream separation, and an upgrade warning.) -- satisfied: yes
- AC-10.3 (non-test) VERSION reads 0.5.0; issue 0001 closed with a Resolutions section referencing ST0011 -- evidence: `intent issues show 0001` (The Resolutions section records the one deliberate departure from the issue's proposed fix (halt in `main/1` rather than at the escript boundary, so downstream inherits the fix from a dependency bump alone) and names the four remaining A13-class instances rather than implying the class is fully closed. Its reproduction claim was re-run against the built escript: exit 1.) -- satisfied: yes
- AC-10.4 (non-test) E1-E8 probe set re-run post-fix with new outcomes recorded -- evidence: impl.md probe table (All eight re-run against the built 0.5.0 escript; table in impl.md.) -- satisfied: yes

### WP-11 -- Closing batch: A13 residue, renderer dialect, width pins, changelog gap (status: Done)

- AC-11.1 (test) The last four A13-class paths return failure through the outcome channel rather than as display text, **and each of those failure branches is reachable** -- `sys.flush` (A24), `cfg.list` (A19), `Arca.Cli.Command.BaseSubCommand` (A18) and `Arca.Cli.Configurator.Coordinator` (A20, both `inject_subcommands/2` and the silently-skipped command in `update_command_names/3`) -- satisfied: yes (computed)
- AC-11.2 (test) A context that reports failure through **either** of its two channels -- `Ctx.add_error/2` or an `{:error, message}` output item -- emits a line matching `^error:` in the form `error: <command>: <message>` under both text styles, alongside the existing `✗` block; `:json` stays structured and unchanged -- satisfied: yes (computed)
- AC-11.3 (test) Renderer tests do not depend on the width of the terminal that launched them -- satisfied: yes (computed)
- AC-11.4 (non-test) CHANGELOG documents the six downstream-relevant changes vc's reverse walk found undocumented -- evidence: CHANGELOG.md "For command authors" section (Four majors (`execute_command/5` return shape, `BaseSubCommand` error tuples, the `namespace_command` namespace and return-value change, spinner resolution at Ctx build) and two minors (declaration-order argv, exact-match REPL history) in one block addressed to command authors rather than scattered.) -- satisfied: yes

### WP-12 -- One predicate for Ctx failure (status: Done)

- AC-12.1 (test) Exactly one authority decides whether a context failed: `Arca.Cli.Ctx.outcome/1`, with `Ctx.failed?/1` as its boolean reduction. The OS exit status, the `error:` dialect line in both text renderers, and the JSON status field all derive from it, and no site reimplements the rule -- satisfied: yes (computed)
- AC-12.2 (test) In both text styles, a line matching `^error:` appears **if and only if** the context failed, across every combination of failure channel and completion state; the `✗` marker renders unconditionally, so gating the dialect line can never swallow a recorded error -- satisfied: yes (computed)
- AC-12.3 (test) The JSON status field is present for every context and equals `Ctx.outcome/1`, so a machine consumer and the exit status can never disagree -- satisfied: yes (computed)

### WP-13 -- Config load diagnosis survives to the user (status: Done)

- AC-13.1 (test) When configuration cannot be loaded, the `error:` line names why, and both commands that read settings give the same reason for the same failure -- satisfied: yes (computed)
- AC-13.2 (test) No exception struct reaches user-facing output on a configuration failure -- satisfied: yes (computed)
- AC-13.3 (non-test) The messages this makes visible follow the ratified dialect -- evidence: `arca_cli.ex` `load_settings/0`, lowercased, with `reason_text/1` in place of `inspect/1` (A binary reason is already the message and is used as-is, because `inspect/1` wraps it in quotes the dialect does not carry. **Third instance in this thread of unswallowing a failure exposing wording nobody had read**) -- satisfied: yes

### WP-14 -- Pin the arca_config contract (status: Done)

- AC-14.1 (test) The arca_config surface arca_cli depends on is stated in one place and asserted, so a dependency bump that removes or renames any of it fails a test rather than a user's command -- satisfied: yes (computed)
- AC-14.2 (test) The liveness probe in `config_available?/0` is pinned, and the pin is checked against what the probe actually names -- satisfied: yes (computed)
- AC-14.3 (non-test) `Arca.Cli.load_settings/0` reaches the config server through the facade, not `Arca.Config.Server.reload/0` -- evidence: `arca_cli.ex` `load_settings/0` ((A30). `run/1` loads settings before dispatch for every command, so that call was on the path for every invocation of this CLI. `Arca.Config.reload/0` delegates to the identical place and exists in both the pinned and the unreleased arca_config, so this is a pure de-coupling with no behaviour change. Two Server calls remain because no facade equivalent exists in the pinned version) -- satisfied: yes
- AC-14.4 (non-test) No shipped documentation instructs a reader to call a function absent from the pinned dependency -- evidence: `cli_command_helper.ex` `@moduledoc` ((A31). The example called `Arca.Config.get_config_location/0`, which is not defined anywhere in the pinned arca_config (`function_exported?` false at runtime) and exists only in the unreleased one; `cli_command_helper.ex` ships in `lib/`. It now uses `Arca.Config.Cfg.config_file/0`, present in both.) -- satisfied: yes

### WP-15 -- Absorb the arca_config 0.3.0 error contract (status: Done)

- AC-15.1 (test) No arca_config error term reaches user-facing output as an Elixir value; every one is rendered as a sentence -- satisfied: yes (computed)
- AC-15.2 (test) A fresh install with no configuration file runs silently and successfully; only a configuration that exists and cannot be read fails -- satisfied: yes (computed)
- AC-15.3 (test) A failure states its reason once -- satisfied: yes (computed)

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

- AT-07.1 `test/arca_cli/dead_code_gate_test.exs, describe "purged symbols` -- covers AC-07.1 -- status: green -- (AC-07.1)" (7 tests) -- One test per purged cluster rather than one omnibus grep, so a partial revert names which cluster came back.
- AT-07.2 `test/arca_cli/dead_code_gate_test.exs, describe "dependency prune` -- covers AC-07.2 -- status: green -- (AC-07.2)" (2 tests) -- Split in two because the AC is: absent from `mix.exs` (all ten), and absent from `mix.lock` (only the three with no other dependant). See the AC-07.2 amendment above.
- AT-07.3 (legacy) test/arca_cli/dead_code_gate_test.exs::"invariant: the scanner finds strings that are genuinely present" -- covers the gate itself -- status: green -- Without it, a scanner that silently matched nothing would report every invariant above as satisfied.

### WP-08 -- One error-formatting pipeline (status: Done)

- AT-08.1 `test/arca_cli/error_format_test.exs` -- covers AC-08.1 -- status: green -- (24 tests)
- AT-08.2 `test/arca_cli/error_format_test.exs` -- covers AC-08.2 -- status: green -- (same file, "reasons are text" describe)
- AT-08.3 `test/arca_cli/exit_code_test.exs` -- covers AC-08.3 -- status: green -- (18 tests, "commands that report failure as a plain string" describe)

### WP-09 -- Remove test-env branching from lib (status: Done)

- AT-09.1 `test/arca_cli/no_test_env_gate_test.exs` -- covers AC-09.1 -- status: green -- (4 tests) -- Proven to discriminate: a temporary `Mix.env()` added to `output.ex` turned it red naming `lib/arca_cli/output.ex:217`, and removing it turned it green. Carries its own control test, so a scanner that silently matched nothing could not report the invariant as satisfied.
- AT-09.2 (legacy) test/arca_cli/cli/arca_cli_test.exs::"settings.all reports the settings actually in force" -- covers AC-09.2 -- status: green -- Written in place of the planned new file: the existing test was the defect, accepting any of three outputs including the fabricated one, so replacing it removes the false green rather than leaving it beside a new test.
- AT-09.3 (legacy) test/arca_cli/no_test_env_gate_test.exs::"invariant: settings come from configuration, not from application env" -- covers AC-09.3 -- status: green -- 717 green, 10 consecutive runs (6 piped, 4 pty). -- The AC has two halves and they need different kinds of evidence: that the mechanism is gone is a property of the source, asserted by this test; that the suite is green without it is the run itself
- AT-09.4 `test/arca_cli/testing/cli_fixtures_pattern_test.exs` -- covers AC-09.4 -- status: green -- (9 tests) -- (fixed early, in WP-02, because it blocked the version fixture)

### WP-10 -- Docs, changelog, and 0.5.0 release (status: Done)

_(no tests in this group)_

### WP-11 -- Closing batch: A13 residue, renderer dialect, width pins, changelog gap (status: Done)

- AT-11.1 (legacy) test/arca_cli/outcome_channel_test.exs, describe "A18: the shared subcommand base" (2 tests) + describe "A20: the configurator coordinator" (5 tests) -- covers AC-11.1 -- status: green -- that the original config is NOT returned as though injection had succeeded. -- Behavioural, not textual: a malformed args map drives the real `BaseSubCommand` failure branch, and a probe module whose `config/0` returns the wrong shape drives both coordinator branches. The A20 tests assert the negative that matters
- AT-11.2 (legacy) test/arca_cli/outcome_channel_test.exs, describe "gate: the failure-as-display-text constructs stay gone" (2 tests) -- covers AC-11.1 -- status: green -- Carries its own control test, so a scanner that silently matched nothing could not report the invariant as satisfied. What it proves is bounded and stated in the file: these four constructs cannot return, not that a new one cannot appear.
- AT-11.3 `test/arca_cli/output/ansi_renderer_test.exs, describe "render/1 with context errors"` -- covers AC-11.2 -- status: green -- (5 tests) -- The first is a regression test for A25 stated as its own assertion (`refute render(ctx) == ""`), separate from the dialect assertions, so a future change that renders *something* wrong is distinguishable from one that renders nothing.
- AT-11.4 (legacy) test/arca_cli/output/plain_renderer_test.exs::"the dialect line names the command when the context has one" + ::"the dialect line starts a line, so `grep '^error:'` finds it" -- covers AC-11.2 -- status: green -- The grep invariant is asserted against ANSI-stripped output in the ansi test and raw output in the plain test, because greppability is the actual requirement and escape codes would defeat it.
- AT-11.5 `test/arca_cli/output/plain_renderer_test.exs, describe "render_item/1 - table width"` -- covers AC-11.3 -- status: green -- (2 tests) -- Asserts the renderer copes at 40 columns and that a wide width keeps every column on one line, which is the property the five pinned order tests depend on.
- AT-11.6 `test/arca_cli/history/degradation_test.exs, describe "sys.flush with History down"` -- covers the reachability half of AC-11.1 -- status: green -- (3 tests) -- Lives beside the unregister seam that makes it possible rather than with the other A13 coverage, because a failure branch is only covered if something can drive it. Added after vc proved the first A24 fix inert.
- AT-11.7 `test/arca_cli/output/renderer_parity_test.exs, the` -- covers AC-11.2 -- status: green -- @failure_channels` x `@text_styles` cross-product (4 tests) + describe "the dialect line means failure, not decoration" (1 test) -- Written as a cross-product rather than as separate assertions because the completeness claim about this dialect has now been wrong twice, and both times the untested *combination* was the broken one. A third failure channel added later needs a row in `@failure_channels` and fails until it has one.

### WP-12 -- One predicate for Ctx failure (status: Done)

- AT-12.1 `test/arca_cli/output/renderer_parity_test.exs, the` -- covers AC-12.1 -- status: green -- @outcome_table` rows (8 tests) -- This table exists because AT-12.2 compares the renderers against `Ctx.outcome/1`, which proves the four sites AGREE but cannot prove the authority is right: both sides would move together. The expected outcomes here are literals, so a change to `Ctx.outcome/1` has to be argued for in this table rather than silently ratified by the tests that depend on it.
- AT-12.2 `test/arca_cli/output/renderer_parity_test.exs, the` -- covers AC-12.2 -- status: green -- the axis that discriminated was the one held constant, and A28 walked straight through it. Each test asserts the biconditional and, separately, that the failure text survived. -- @failure_channels` x `@completions` x `@text_styles` cross-product (16 tests) -- Replaces AT-11.7's `channel x style` product, which pinned `complete(:error)` on every row
- AT-12.3 `test/arca_cli/output/renderer_parity_test.exs, describe "the JSON status is the same authority as the exit status"` -- covers AC-12.3 -- status: green -- (8 tests) -- Asserts against `Ctx.outcome/1` for every channel x completion pair, which is what catches the dropped-key case: a never-completed failing context decoded to `nil` before the fix, because the raw status field was `nil` and the nil-rejection removed it from the document.

### WP-13 -- Config load diagnosis survives to the user (status: Done)

- AT-13.1 `test/arca_cli/config_diagnosis_test.exs, describe "a load failure reports its reason` -- covers AC-13.1 -- status: green -- (A29)" -- Drives a real unparseable config file through a subprocess rather than mocking the config server, which is possible because the corrupt-file trigger works on the pinned dependency.
- AT-13.2 `test/arca_cli/config_diagnosis_test.exs, the per-command "leaks no exception struct at the user" tests` -- covers AC-13.2 -- status: green -- (2) -- Matches any `%Module{` shape rather than `%MatchError{` specifically, so a different leaked struct fails too.
- AT-13.3 `test/arca_cli/config_diagnosis_test.exs, describe "a command that does not read configuration"` -- covers AC-13.1 -- status: green -- (2 tests) -- Asserts both halves of the startup-warning behaviour: a config-independent command still exits 0 with a broken config, and the warning it emits names the reason.
- AT-13.4 (legacy) test/arca_cli/config_diagnosis_test.exs::"invariant: the broken config is the one the CLI reads" -- covers the seam itself -- status: green -- `config/dotenv.exs` calls `System.put_env/2` under `:dev` and `:test`, overwriting `ARCA_CLI_CONFIG_PATH` from the parent environment, so a child cannot be steered by exporting it. The seam sets it inside the evaluated code, after config evaluation. Without this test a child that never reached the broken config would produce plausible-looking failures.

### WP-14 -- Pin the arca_config contract (status: Done)

- AT-14.1 `test/arca_cli/config_contract_test.exs, describe "the facade surface arca_cli calls"` -- covers AC-14.1 -- status: green -- (4 tests) -- One test per call site rather than one omnibus assertion, so a bump names which function went rather than reporting that something did.
- AT-14.2 `test/arca_cli/config_contract_test.exs, describe "the Server internals arca_cli reaches for"` -- covers AC-14.1, AC-14.3 -- status: green -- (2 tests) -- Held separate from the facade list so that reaching past the public module stays visible as an exception rather than becoming precedent. vc established that arca_config's own contract test pins neither of these.
- AT-14.3 `test/arca_cli/config_contract_test.exs, describe "the liveness probe"` -- covers AC-14.2 -- status: green -- (2 tests) -- Two assertions, not one: that the probed function exists, and that `config_available?/0` still probes the function this file pins. Without the second, changing the probe would leave the first true of arca_config while no longer describing anything this CLI relies on.

### WP-15 -- Absorb the arca_config 0.3.0 error contract (status: Done)

- AT-15.1 (legacy) test/arca_cli/error_format_test.exs::"failure: a setting that does not exist" -- covers AC-15.1 -- status: green -- Not a new test: it is the existing dialect assertion, which went red at the bump naming the raw tuple it had started printing. A test that already asserted the right thing and simply began failing is the best possible evidence that the contract changed.
- AT-15.2 (legacy) test/arca_cli/commands/cli_debug_persistence_test.exs::"invariant: a fresh install starts with debug off" -- covers AC-15.2 -- status: green -- the release trap, inside the suite. -- Also pre-existing, also went red at the bump. It drives the built escript, which is why it kept failing after the source was already correct
- AT-15.3 `test/arca_cli/config_diagnosis_test.exs, the per-command "states the reason once, not twice" tests` -- covers AC-15.3 -- status: green -- (2) -- Proven to discriminate: restoring the double prefix turns exactly those two rows red and no others.

---

_Generated by Intent v3.0.0 from `thread.json`. Do not edit this file -- it is rendered from the model, and `intent doctor` reports any hand-edit as skew._
