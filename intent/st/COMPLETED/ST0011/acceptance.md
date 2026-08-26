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

**AC-07.2 amendment (cc, 2026-08-04) -- ACKED BY hv as written (relayed by vc, 16:05 rulings).** The AC cannot be met as literally written, and this was not knowable when it was drafted. Of the ten pruned dependencies, only three (`dotenv`, `logger_file_backend`, `logger_backends`) can leave `mix.lock`. The other seven -- `castore`, `certifi`, `elixir_uuid`, `pathex`, `table_rex`, `ucwidth`, `ok` -- are dependencies of `arca_config`, so they stay resolved no matter what this project declares. Removing them from `mix.exs` makes them arca_config's business, which is the most this repository can do about them.

The AC is therefore read as: pruned deps are absent from `mix.exs`, and absent from `mix.lock` where nothing else depends on them. Both halves are asserted by AT-07.2, and the second half names its three deps explicitly rather than hiding the limit. Flagged rather than quietly satisfied, because reading it the loose way would have let a future reader believe the lock was clean when it is not.

The last sentence of this amendment used to read "hv can rule the remainder into the arca_config work". **That is withdrawn**, on vc's retraction of its own earlier reading (2026-08-04): the seven are used by arca_config, so they are not residue waiting to be pruned there and the remainder does not pass to that repository. The changelog line stays correct permanently rather than provisionally.

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

> AC-10.1 amendment (2026-08-04, WP-11): the "Known limitations" entry this AC cites named four commands that still exited 0 on failure. hv subsequently ruled all fixes into 0.5.0, so WP-11 fixed them and the section now records that the class is closed. The AC remains satisfied against the changed section; the citation above is left as written so the amendment is visible rather than silent.

### WP-11 -- Closing batch: A13 residue, renderer dialect, width pins, changelog gap (status: Complete)

- AC-11.1 (test) The last four A13-class paths return failure through the outcome channel rather than as display text, **and each of those failure branches is reachable** -- `sys.flush` (A24), `cfg.list` (A19), `Arca.Cli.Command.BaseSubCommand` (A18) and `Arca.Cli.Configurator.Coordinator` (A20, both `inject_subcommands/2` and the silently-skipped command in `update_command_names/3`) -- evidence: AT-11.1, AT-11.2, AT-11.6 -- satisfied: yes.
  - **The reachability half of this AC was added after the first attempt failed verification, and it is the half that mattered.** As first written the AC asked only that the paths return tuples. A24 satisfied that and could not execute: `flush_command_history/0` discarded `History.flush_history/0`'s return value and answered `{:ok, :flushed}` unless something raised, which nothing does -- WP-05's own A5 fix converts the exit into a tagged tuple. So the error branch was unreachable, `sys.flush` still reported success with History demonstrably down, and the construct gate covering it could only ever prove the old string was gone. Found by vc; reproduced here before fixing.
  - The claim that A19 and A24 had "no seam to drive without mocking" was wrong. vc pointed at `degradation_test.exs:28-30` -- unregister the History name, which is cc's own WP-05 pattern and involves no mocking at all. A24 is now driven behaviourally through that seam (AT-11.6). A19 is genuinely reachable too: `cfg_commands.ex:74` strict-matches `{:ok, settings} = Arca.Cli.load_settings()`, so an error tuple raises MatchError into the rescue and returns `{:error, :load_failed, _}`.
- AC-11.2 (test) A context that reports failure through **either** of its two channels -- `Ctx.add_error/2` or an `{:error, message}` output item -- emits a line matching `^error:` in the form `error: <command>: <message>` under both text styles, alongside the existing `✗` block; `:json` stays structured and unchanged -- evidence: AT-11.3, AT-11.4, AT-11.7 -- satisfied: yes.
  - **Both halves of this AC were found wrong before they were found right, and by different routes.** Implementing hv's ruling surfaced A25: the `:ansi` renderer read `ctx.output` and nothing else, so an error-only context rendered to the empty string. Then vc found that the fix covered only one of the two failure channels: `cli.error ctx` reports through `Ctx.add_output({:error, _})`, so `ctx.errors` was empty, and the command exited 1 with zero `^error:` matches. The first wording of this AC said "Ctx-reported failures" and meant only one of the two ways a Ctx reports failure.
  - **Scope decision (cc), from vc's two candidate shapes plus a third.** vc offered: emit the dialect line for every `{:error, _}` output item, or fold such items into `ctx.errors` for a single channel. Neither was taken. Folding into `ctx.errors` puts `errors: [...]` into the JSON of a *successful* command that displays per-item failures, which misreports it to structured consumers. Emitting unconditionally makes `^error:` mean "a red line was printed" rather than "the command failed", so the grep over-reports. The dialect line is therefore emitted for an `{:error, _}` output item **when the context's status is `:error`**, which keeps the grep meaning exactly "this command failed" and leaves `add_output/2` semantics untouched. Both the positive and the negative are asserted (AT-11.7).
    - **Superseded by AC-12.1 (A28).** The reasoning above is sound and the conclusion was half-applied: the guard went on the output-item channel and `add_error/2` was left unguarded, so the two harms this bullet cites to justify the guard were both still committed by the other channel. vc caught it on re-verification. The rule survives; what changed is that it is now applied to both channels through one predicate, and the predicate is the one that sets the exit status. AT-11.7 was replaced by AT-12.2 for the same reason: it asserted presence where it needed to assert the biconditional.
  - **Bounded, and the bound is stated rather than left to be discovered.** A context that completes `:error` while reporting no message through either channel emits no dialect line, because there is no message to put in one. That is a command-authoring gap, not a renderer one, and no command in this repository does it.
- AC-11.3 (test) Renderer tests do not depend on the width of the terminal that launched them -- evidence: AT-11.5 plus the width matrix below -- satisfied: yes. Layout-sensitive tests pin `:max_width`, which makes terminal width not an input at all: `owl_table_helper.ex:132` reads `Keyword.get(opts, :max_width) || Owl.IO.columns() || 80`, so a pinned width short-circuits the terminal query. The mechanism was reproduced deterministically before being fixed, by rendering at a pinned width of 40: the fourth column wraps to one character per row, its name leaves the header line, `:binary.match/2` returns `:nomatch` and the test dies in `elem/2`.
  - vc's N2 named `plain_renderer_test.exs`. Fixing only that file left the suite still failing at 40 columns, in `ansi_renderer_test.exs:265` -- the same defect in the sibling renderer's tests, which vc's repro had not reached. Both files are now pinned throughout (5 sites in plain, 13 in ansi) rather than at the one line that happened to fail. **A repro names an instance; it does not bound the class.**
  - Width matrix, seed 11, full suite: 40 / 60 / 100 / 200 columns under a pty and piped -- 728 green at every width.
- AC-11.4 (non-test) CHANGELOG documents the six downstream-relevant changes vc's reverse walk found undocumented -- evidence: CHANGELOG.md "For command authors" section -- satisfied: yes. Four majors (`execute_command/5` return shape, `BaseSubCommand` error tuples, the `namespace_command` namespace and return-value change, spinner resolution at Ctx build) and two minors (declaration-order argv, exact-match REPL history) in one block addressed to command authors rather than scattered.

### WP-12 -- One predicate for Ctx failure (status: Complete)

- AC-12.1 (test) Exactly one authority decides whether a context failed: `Arca.Cli.Ctx.outcome/1`, with `Ctx.failed?/1` as its boolean reduction. The OS exit status, the `error:` dialect line in both text renderers, and the JSON status field all derive from it, and no site reimplements the rule -- evidence: AT-12.1, plus the deletion of the private `ctx_outcome/1` from `arca_cli.ex` -- satisfied: yes.
  - **The finding was vc's; the diagnosis is not the one vc filed.** vc reported an asymmetry: the dialect line was gated on `status: :error` for the `{:error, _}` output-item channel and not gated at all for `add_error/2`, so the same message rendered differently depending only on which channel the author reached for. That is real and it reproduced. But the frame -- "which status should gate the dialect line" -- understated it. Four sites answered "did this ctx fail" independently: `ctx_outcome/1` at `arca_cli.ex:818` (exit status), `render_errors/1` (non-empty errors), `render_output_item/2` (`status: :error`), and `json_renderer.ex:41` (raw `ctx.status`). Two of the four disagreed with the exit status. The duplication was never the two channels -- vc was right that `add_error/2` and `add_output({:error, _})` are different intents and should not merge -- it was the predicate, answered four ways.
  - Driven before it was fixed, `channel x status x style`, ANSI stripped: `add_error |> complete(:ok)` exited **0** while printing `error:` -- the exact inverse of A13, breaking the same correspondence from the other end. `add_error` with no `complete/2` exited **1** while its JSON carried **no status key at all**, because the raw field was `nil` and `to_json_map/1` rejects nil values. That second row was outside the matrix vc filed.
  - Neither of vc's two proposed shapes was taken, for stated reasons. Gating `render_errors/1` on `status == :error` drops the `✗` block along with the dialect line, which is a silent swallow (IN-AG-NO-SILENT-001) -- vc flagged this against its own option. Making `add_error/2` set `status: :error` does not make the bad row unrepresentable as claimed, because `add_error |> complete(:ok)` remains writable and vc's own "overridable by a later `complete/2`" concedes it; it removes the accidental case only. The shape taken instead: **the dialect line is conditional, the visible marker never is**, applied identically to both channels, with the condition being the same predicate that sets the exit code.
- AC-12.2 (test) In both text styles, a line matching `^error:` appears **if and only if** the context failed, across every combination of failure channel and completion state; the `✗` marker renders unconditionally, so gating the dialect line can never swallow a recorded error -- evidence: AT-12.2 -- satisfied: yes.
  - The biconditional is the point. AC-11.2 asserted presence only, and presence-only is what let this through: the broken row printed the line and passed. An over-report and an under-report are the same defect measured from opposite ends, and only a biconditional catches both.
  - Bounded: this makes `^error:` present at-least-once for a failure, not exactly-once. A context reporting through both channels emits one line per recorded message (two for two), which is consistent -- it recorded two failures. Nothing in this repository does it.
- AC-12.3 (test) The JSON status field is present for every context and equals `Ctx.outcome/1`, so a machine consumer and the exit status can never disagree -- evidence: AT-12.3 -- satisfied: yes. The `:dump` style deliberately keeps reporting the raw `ctx.status`, including `nil`: it is a debugging dump of the struct, and showing the field as it actually is is its job.

### WP-13 -- Config load diagnosis survives to the user (status: Complete)

- AC-13.1 (test) When configuration cannot be loaded, the `error:` line names why, and both commands that read settings give the same reason for the same failure -- evidence: AT-13.1, AT-13.3 -- satisfied: yes. `cfg.list` strict-matched `{:ok, settings} = Arca.Cli.load_settings()`, so a legitimate error tuple raised a MatchError into a bare rescue that returned the constant `"Unknown error loading settings"`, while its sibling `settings.all` reported the reason correctly off the same call.
  - **Filed as dormant; it was live.** vc found this building against the unreleased arca_config and scoped it as going live at the dep bump, because the pinned arca_config falls back silently when a config file is MISSING. A config file that EXISTS and does not parse reaches the identical path on the pinned dependency, so the finding needed neither the bump nor a local arca_config to reproduce. That is what makes this a WP now rather than a note attached to the bump, and hv's single-bump ruling is not engaged: nothing here changes a dependency.
  - Scope taken beyond the filed finding, deliberately: the startup warning in `run/1` discarded the reason too (`Logger.warning("Error loading settings")` with no reason at all), and that is the same defect one level up. It is what made vc's unfiled `about` / `cli.status` observation noisy-but-useless rather than merely noisy. The eager settings load itself is NOT changed -- every command loading settings before dispatch is a design question, not a defect, and Logger writes to stderr (A17) so it cannot corrupt a pipe.
- AC-13.2 (test) No exception struct reaches user-facing output on a configuration failure -- evidence: AT-13.2 -- satisfied: yes. The rescue in `Arca.Cli.load_settings/0` reports `Exception.message/1` rather than `inspect(e)`, and the rescue that leaked a `%MatchError{}` is gone entirely rather than reworded.
- AC-13.3 (non-test) The messages this makes visible follow the ratified dialect -- evidence: `arca_cli.ex` `load_settings/0`, lowercased, with `reason_text/1` in place of `inspect/1` -- satisfied: yes. A binary reason is already the message and is used as-is, because `inspect/1` wraps it in quotes the dialect does not carry. **Third instance in this thread of unswallowing a failure exposing wording nobody had read** -- the coordinator's six messages and History's four were the first two.

### WP-14 -- Pin the arca_config contract (status: Complete)

- AC-14.1 (test) The arca_config surface arca_cli depends on is stated in one place and asserted, so a dependency bump that removes or renames any of it fails a test rather than a user's command -- evidence: AT-14.1, AT-14.2 -- satisfied: yes. arca_cli tracks arca_config by git branch and every call resolves at runtime, so there is no compiler error to catch this; that is what makes an explicit pin worth having rather than redundant.
- AC-14.2 (test) The liveness probe in `config_available?/0` is pinned, and the pin is checked against what the probe actually names -- evidence: AT-14.3 -- satisfied: yes. `function_exported?(Arca.Config, :register_change_callback, 2)` has no caller in this repository -- WP-07 deleted the callback subsystem -- so a call-graph search from the arca_config side cannot find this consumer. Retiring it there silently flips `config_available?` to false and degrades every `save_settings`. Previously a written watch-out on the cc board; now mechanical.
- AC-14.3 (non-test) `Arca.Cli.load_settings/0` reaches the config server through the facade, not `Arca.Config.Server.reload/0` -- evidence: `arca_cli.ex` `load_settings/0` -- satisfied: yes (A30). `run/1` loads settings before dispatch for every command, so that call was on the path for every invocation of this CLI. `Arca.Config.reload/0` delegates to the identical place and exists in both the pinned and the unreleased arca_config, so this is a pure de-coupling with no behaviour change. Two Server calls remain because no facade equivalent exists in the pinned version -- `Server.start_link/1` (none in either) and `Server.delete/1` (facade only in the unreleased one) -- and both are pinned by AT-14.2 rather than left implicit.
- AC-14.4 (non-test) No shipped documentation instructs a reader to call a function absent from the pinned dependency -- evidence: `cli_command_helper.ex` `@moduledoc` -- satisfied: yes (A31). The example called `Arca.Config.get_config_location/0`, which is not defined anywhere in the pinned arca_config (`function_exported?` false at runtime) and exists only in the unreleased one; `cli_command_helper.ex` ships in `lib/`. It now uses `Arca.Config.Cfg.config_file/0`, present in both.
  - Reported here as documentation rather than as the live crash it first looked like. Line 350 sits inside the `@moduledoc`, which runs to line 375. Checking reachability before writing it up is what caught that, and it is the same discipline A26 taught at greater cost.

### WP-15 -- Absorb the arca_config 0.3.0 error contract (status: Complete)

- AC-15.1 (test) No arca_config error term reaches user-facing output as an Elixir value; every one is rendered as a sentence -- evidence: AT-15.1, plus the escript probe in `WP/15/info.md` -- satisfied: yes (A32). 0.3.0 ratified `{:error, {:config, reason, detail}}`, so `settings.get nosuchkey` answered `cannot read setting nosuchkey: {:config, :not_found, ["nosuchkey"]}`. Rendering goes through one function, `config_reason/1`, delegating to `Arca.Config.Error.message/1`, which is total by construction so reporting an error cannot fail on the shape of the error.
  - The clause that classified a missing key by testing whether the message contained the words "not found" is deleted, matching the atom instead. arca_config's own rationale for the new type names this repository as the reason it exists: matching on English prose meant rewording a message there was a silent breaking change to behaviour here.
- AC-15.2 (test) A fresh install with no configuration file runs silently and successfully; only a configuration that exists and cannot be read fails -- evidence: AT-15.2 -- satisfied: yes (A33). Before the bump a missing config silently fell back to a different config and reported success; arca_config's WP-04 removed that, correctly. But `run/1` loads settings for every command, so every invocation on a fresh install then warned about an entirely normal state. An absent config reports `{:ok, %{}}`, because "there are none" is the honest answer to what the settings are.
  - Bounded deliberately: this classifies `:enoent` only. A config that exists and cannot be parsed still fails loudly with its reason -- the A29 case -- and AT-13.1 drives that with an unparseable file rather than a missing one, so the two cases are covered by different tests and cannot be conflated.
- AC-15.3 (test) A failure states its reason once -- evidence: AT-15.3 -- satisfied: yes (A34, self-inflicted). `Arca.Config.Error.message/1` renders a complete phrase including its own prefix, and wrapping it in ours printed the sentence twice in one line.
  - **The existing A29 tests drive this exact path and stayed green.** They assert the reason *appears*, and a doubled message still contains the reason. Third time in this thread an assertion has been satisfied by the malformed output it existed to reject, after the `%MatchError{}` leak containing its own reason string and AT-11.7 asserting presence where it needed a biconditional. Found by escript probe.

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

### WP-11

- AT-11.1 test/arca_cli/outcome_channel_test.exs, describe "A18: the shared subcommand base" (2 tests) + describe "A20: the configurator coordinator" (5 tests) -- covers AC-11.1 -- status: green. Behavioural, not textual: a malformed args map drives the real `BaseSubCommand` failure branch, and a probe module whose `config/0` returns the wrong shape drives both coordinator branches. The A20 tests assert the negative that matters -- that the original config is NOT returned as though injection had succeeded.
- AT-11.2 test/arca_cli/outcome_channel_test.exs, describe "gate: the failure-as-display-text constructs stay gone" (2 tests) -- covers AC-11.1 -- status: green. Carries its own control test, so a scanner that silently matched nothing could not report the invariant as satisfied. What it proves is bounded and stated in the file: these four constructs cannot return, not that a new one cannot appear.
- AT-11.3 test/arca_cli/output/ansi_renderer_test.exs, describe "render/1 with context errors" (5 tests) -- covers AC-11.2 -- status: green. The first is a regression test for A25 stated as its own assertion (`refute render(ctx) == ""`), separate from the dialect assertions, so a future change that renders *something* wrong is distinguishable from one that renders nothing.
- AT-11.4 test/arca_cli/output/plain_renderer_test.exs::"the dialect line names the command when the context has one" + ::"the dialect line starts a line, so `grep '^error:'` finds it" -- covers AC-11.2 -- status: green. The grep invariant is asserted against ANSI-stripped output in the ansi test and raw output in the plain test, because greppability is the actual requirement and escape codes would defeat it.
- AT-11.5 test/arca_cli/output/plain_renderer_test.exs, describe "render_item/1 - table width" (2 tests) -- covers AC-11.3 -- status: green. Asserts the renderer copes at 40 columns and that a wide width keeps every column on one line, which is the property the five pinned order tests depend on.
- AT-11.6 test/arca_cli/history/degradation_test.exs, describe "sys.flush with History down" (3 tests) -- covers the reachability half of AC-11.1 -- status: green. Lives beside the unregister seam that makes it possible rather than with the other A13 coverage, because a failure branch is only covered if something can drive it. Added after vc proved the first A24 fix inert.
- AT-11.7 test/arca_cli/output/renderer_parity_test.exs, the `@failure_channels` x `@text_styles` cross-product (4 tests) + describe "the dialect line means failure, not decoration" (1 test) -- covers AC-11.2 -- status: green. Written as a cross-product rather than as separate assertions because the completeness claim about this dialect has now been wrong twice, and both times the untested *combination* was the broken one. A third failure channel added later needs a row in `@failure_channels` and fails until it has one.
  - Proven to discriminate: with the `status: :error` guard temporarily changed to an unmatchable atom, exactly the two `{:error, _} output item` rows went red naming the channel and style, and both went green again on restore. A passing test is not evidence until it has been shown it can fail.
- Coverage: AC-11.4 is non-test (evidence on the AC line)

### WP-12

- AT-12.1 test/arca_cli/output/renderer_parity_test.exs, the `@outcome_table` rows (8 tests) -- covers AC-12.1 -- status: green. This table exists because AT-12.2 compares the renderers against `Ctx.outcome/1`, which proves the four sites AGREE but cannot prove the authority is right: both sides would move together. The expected outcomes here are literals, so a change to `Ctx.outcome/1` has to be argued for in this table rather than silently ratified by the tests that depend on it.
- AT-12.2 test/arca_cli/output/renderer_parity_test.exs, the `@failure_channels` x `@completions` x `@text_styles` cross-product (16 tests) -- covers AC-12.2 -- status: green. Replaces AT-11.7's `channel x style` product, which pinned `complete(:error)` on every row -- the axis that discriminated was the one held constant, and A28 walked straight through it. Each test asserts the biconditional and, separately, that the failure text survived.
  - Proven to discriminate, twice, by mutation. Forcing the plain renderer's dialect line unconditional again turned exactly six tests red: the five `plain` rows whose outcome is not `:error`, plus the retained "succeeding context" test which catches the same break independently. Zero `ansi` rows moved. Restoring turned them green.
- AT-12.3 test/arca_cli/output/renderer_parity_test.exs, describe "the JSON status is the same authority as the exit status" (8 tests) -- covers AC-12.3 -- status: green. Asserts against `Ctx.outcome/1` for every channel x completion pair, which is what catches the dropped-key case: a never-completed failing context decoded to `nil` before the fix, because the raw status field was `nil` and the nil-rejection removed it from the document.
  - Proven to discriminate: reverting `json_renderer.ex` to the raw `ctx.status` turned exactly the two "never completed" rows red, and no others.
- Coverage: complete

### WP-13

- AT-13.1 test/arca_cli/config_diagnosis_test.exs, describe "a load failure reports its reason (A29)" -- the per-command reason tests (2) plus "both settings readers report the same reason" (1) -- covers AC-13.1 -- status: green. Drives a real unparseable config file through a subprocess rather than mocking the config server, which is possible because the corrupt-file trigger works on the pinned dependency.
- AT-13.2 test/arca_cli/config_diagnosis_test.exs, the per-command "leaks no exception struct at the user" tests (2) -- covers AC-13.2 -- status: green. Matches any `%Module{` shape rather than `%MatchError{` specifically, so a different leaked struct fails too.
- AT-13.3 test/arca_cli/config_diagnosis_test.exs, describe "a command that does not read configuration" (2 tests) -- covers AC-13.1 -- status: green. Asserts both halves of the startup-warning behaviour: a config-independent command still exits 0 with a broken config, and the warning it emits names the reason.
- AT-13.4 test/arca_cli/config_diagnosis_test.exs::"invariant: the broken config is the one the CLI reads" -- covers the seam itself -- status: green. `config/dotenv.exs` calls `System.put_env/2` under `:dev` and `:test`, overwriting `ARCA_CLI_CONFIG_PATH` from the parent environment, so a child cannot be steered by exporting it. The seam sets it inside the evaluated code, after config evaluation. Without this test a child that never reached the broken config would produce plausible-looking failures.
- **The first version of these tests was weaker than it looked, and mutation is what showed it.** Reverting the fix was predicted to turn 4 red and turned 2: the seam test and the two-readers test both passed against the broken code, because the leaked `%MatchError{}` *contains* the reason string, so assertions scanning the whole output found it while the user was still being told "Unknown error loading settings". A check satisfied by the very leak it is meant to forbid. They now read the dialect line specifically -- the user-facing statement -- and the mutation produces the predicted 4. Reverting the startup warning alone turns exactly 1 red.
- Coverage: AC-13.3 is non-test (evidence on the AC line)

### WP-14

- AT-14.1 test/arca_cli/config_contract_test.exs, describe "the facade surface arca_cli calls" (4 tests) -- covers AC-14.1 -- status: green. One test per call site rather than one omnibus assertion, so a bump names which function went rather than reporting that something did.
- AT-14.2 test/arca_cli/config_contract_test.exs, describe "the Server internals arca_cli reaches for" (2 tests) -- covers AC-14.1, AC-14.3 -- status: green. Held separate from the facade list so that reaching past the public module stays visible as an exception rather than becoming precedent. vc established that arca_config's own contract test pins neither of these.
- AT-14.3 test/arca_cli/config_contract_test.exs, describe "the liveness probe" (2 tests) -- covers AC-14.2 -- status: green. Two assertions, not one: that the probed function exists, and that `config_available?/0` still probes the function this file pins. Without the second, changing the probe would leave the first true of arca_config while no longer describing anything this CLI relies on.
- Proven to discriminate by mutation, failing set predicted before each run: adding a function arca_config does not export turns exactly 1 red; repointing `@liveness_probe` at a **different real** function also turns exactly 1 red -- and that is the informative one, because `notify_callbacks/0` genuinely exists, so the existence assertion passed and only the source check caught the drift. A pin that can drift from the code it claims to describe is worth less than no pin.
- Coverage: AC-14.3 and AC-14.4 are non-test (evidence on the AC lines)

### WP-15

- AT-15.1 test/arca_cli/error_format_test.exs::"failure: a setting that does not exist" -- covers AC-15.1 -- status: green. Not a new test: it is the existing dialect assertion, which went red at the bump naming the raw tuple it had started printing. A test that already asserted the right thing and simply began failing is the best possible evidence that the contract changed.
- AT-15.2 test/arca_cli/commands/cli_debug_persistence_test.exs::"invariant: a fresh install starts with debug off" -- covers AC-15.2 -- status: green. Also pre-existing, also went red at the bump. It drives the built escript, which is why it kept failing after the source was already correct -- the release trap, inside the suite.
- AT-15.3 test/arca_cli/config_diagnosis_test.exs, the per-command "states the reason once, not twice" tests (2) -- covers AC-15.3 -- status: green. Proven to discriminate: restoring the double prefix turns exactly those two rows red and no others.
- Coverage: complete

> Verification note for WP-11: the pty route for reproducing vc's 40-column repro was unreliable in this sandbox (`script` returned `tcgetattr/ioctl: Operation not supported on socket` on the second invocation), so the terminal-width dependency was reproduced and closed deterministically at the API instead, by pinning `:max_width`. That is stronger evidence than a green pty run, because it removes the terminal from the input set rather than testing one value of it.
