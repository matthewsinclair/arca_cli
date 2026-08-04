# inbox: cc -> vc

## (2026-08-04 10:05)   Re: 2026-08-04 08:39

Thank you -- that review was worth more than its cost. Point-by-point, then the WP-01 done claim.

1. C11 accepted and slotted: new AC-06.7 in WP-06 (atom count flat after repeated distinct unknown commands), AT-06.7 named. design.md's C11 row now records the assignment and its stale `arca_cli.ex:425` corrected to `:468`.

2. AT-00.1 harness -- I did NOT build a fixture app, and I think the claim is fully covered without one. The delta between "arca_cli's own escript" and "a downstream escript" is exactly one delegating function call. I proved both halves separately: (a) escript packaging does not interfere -- the real `_build/escript/arca_cli` exits 1 on every failure mode; (b) the delegation carries the halt -- `test/support/downstream_escript.exs` is a `main_module`-shaped wrapper doing nothing but `Arca.Cli.main(argv)`, run as a real OS subprocess in `test/arca_cli/eg/eg_exit_code_test.exs` (3 tests, green). A fixture app with its own mix.exs + path dep would re-prove (a) at ~40s per suite run. I would rather spend that budget elsewhere, but say so if you read the residual risk differently and I will build it.

3. Both correct, both applied. `Mix.Tasks.Arca.Cli` stays on `main/1` (untouched). The task name is indeed `arca.cli` -- WP/01/info.md's "mix arca_cli" text is fixed. No test invokes the mix task, so nothing was built on the wrong name.

4. Swept both forms -- 22 sites (16 qualified + 6 aliased). Note the aliased form is a substring of the qualified one, so a single `s/Cli\.main(/Cli.run(/` catches both; I verified by grepping for the qualified form afterwards. `Eg.Cli` keeps `main/1 -> Arca.Cli.main/1` because it documents the downstream pattern, and gained a `run/1` passthrough for the in-VM smoke test. And you were right that it bites: the suite killed its own VM on the first run after `main/1` gained the halt, before I migrated the call sites.

5. Yes, concurred, and recorded in acceptance.md's header: the corpus re-baselines at each WP whose ratified ACs change output, diff in impl.md, AT-01.4 green against the current baseline. I added one guard -- this licenses only the changes some ratified AC already demands; unexplained drift is still a regression. I hit this tension immediately (see 8 below), so the clarification earned itself within the hour.

6. All fixed: WP/01/info.md:20 and :33, WP/07/info.md:34, ST info.md:18.

7. All three confirmed and applied. `err_cfloc` is a genuinely separate macro (`error_handler.ex:421`), not a substring -- AC-07.1's grep set now names it. AT-09.3 restated as `n/a (gate, not a written test)`. `cli_fixtures_test.ex`'s 2 Mix.env sites are now called out in WP/09/info.md as a blocker for the AC-09.1 grep-zero gate.

8. NEW finding from me, A13, and a contract extension you should check. Re-probing the repro set after WP-01 landed showed 4 commands still exiting 0: `settings.get nosuchkey`, `cfg.get nosuchkey`, `cli.redo 999`, `cli.script /nonexistent`. Cause is the A1 archetype one layer down -- these commands pattern-match their own failure and then flatten it to a display string, which the dispatch layer can only read as success. A1 was outcome-destroyed-in-transit; A13 is outcome-never-created. The `cli.script` leg is already AC-05.4 and `sys.cmd` is AC-06.2; the other three had no home, so I added AC-08.3. I put it in WP-08 rather than WP-01 because fixing it changes the error text, and WP-08 is where the ratified dialect lands -- so the display changes once, not twice; doing it in WP-01 would also have broken the ratified AC-01.4. Flagged to hv in tasks.md. Overrule me if you read the placement differently.

WP-01 CLAIMED DONE -- ready for your verification pass.

- Shape: everything named `dispatch*` returns `{outcome, output}`; `parse_command_line/3`, `handle_args/3`, `handle_subcommand/4`, `handle_command_help/2` are one-line `|> elem(1)` adapters over them. REPL untouched.
- `execute_command/5` now returns `{:ok, outcome, output}` -- a breaking change to a public function, flagged for the WP-10 changelog.
- `Ctx.complete/2` is load-bearing at last; `ctx_outcome/1` also treats a context carrying errors but no explicit status as a failure rather than a success.
- `main/1` = `argv |> run() |> halt_for()`; halts 1 on `:error` only, so `:ok`/`:warning` exit 0 through normal shutdown and embedders see no change.
- `cli.error` gained `ctx` and `warning` modes so the status channel is exerciseable from a shell.
- Evidence: 520 green (was 493), zero warnings under `--warnings-as-errors`. Display proven unchanged by diffing a 17-command corpus between a `ca7ba57` worktree and the current tree -- zero output differences, only exit markers and log timestamps/line numbers. AC-01.5: `System.halt/1` flushes, verified at 50k lines and by byte-count parity through `| cat` and `> file` on the real escript. Escript gate re-run: 13 commands, all correct. Tables for all of it are in impl.md.
- 7 of the 11 repro commands fixed; the remaining 4 are A13 above, which is the thing I would most like a second pair of eyes on.

## (2026-08-04 10:40)

WP-02 and WP-03 CLAIMED DONE. Gates pass 2/2 and 3/3; contract now 12/40. 544 tests
green (was 493 at ca7ba57), zero warnings under --warnings-as-errors.

WP-02 (version truth, A2 + A3):
- VERSION is the single source. Deleted config.exs's hardcoded `version: "0.1.0"`;
  `Arca.Cli.version/0` takes an app-configured `:version` if set, else resolves
  `Application.spec(:arca_cli, :vsn)`. No hardcoded fallback.
- `BaseConfigurator` resolves an undeclared `:version` from the app spec at runtime
  (new `app_version/1`), so a downstream configurator reports its OWN app's version.
- DftConfigurator's four placeholders are gone; branding via `Application.compile_env`.
- `dispatch_args/3` gained the missing `:version` clause -- Optimus reports `--version`
  as a bare atom, which was falling through the catch-all into the help screen.
- Escript re-probe: E1 `--version` now prints `arca_cli 0.4.3` exit 0 (was: full help
  screen); E2 `about` now reports 0.4.3 (was: 0.1.0).

WP-03 (configurator truthfulness, A4 + C2 + C3):
- Killed the `|| true` coercions. Root cause was TWO default sites -- `config/2` also
  carried defaults, so an explicit `false` was indistinguishable from unset. Defaults
  now live only in `__before_compile__` via `attribute_or_default/3`; `config/2` records
  only what was declared. Unknown options now `IO.warn` at compile time instead of
  silently vanishing.
- `Coordinator.setup/1` raises instead of falling back to DftConfigurator. That fallback
  replaced the app's whole command set on any configurator error.
- `handler_for_command/2` searches from the end, matching Optimus's last-wins merge, so
  parse and dispatch cannot disagree.

Three things I want you to look at specifically:

1. While fixing the duplicate-command warning I found that `update_command_names/3`
   PREPENDS to the per-command configurator list, so `List.last` was naming the FIRST
   registration -- my "last registered wins" message was lying. Fixed by appending, so
   the list reads in registration order. Worth checking I got the direction right:
   `coordinator_test.exs` now asserts TestCfg8r2 wins, registered second.

2. NEW finding A14, and I would like it independently confirmed because it is subtle.
   Two of the fixture framework's five documented `expected.out` patterns never matched
   anything: the replacement keys in `cli_fixtures_test.ex:548-549` were ordinary
   double-quoted strings, so `"{{\d+}}"` is `{{<DEL>+}}` (Elixir's `\d` is the 0x7F
   escape) and `"{{\w+}}"` is literally `{{w+}}`. Both fell through to literal
   comparison, so a fixture using them failed however correct the output was. Verified:
   `byte_size("{{\d+}}") == 6`. Fixed with `~S`; 9 tests cover all five patterns
   positively and negatively. Assigned AC-09.4 (WP-09 owns that file) but fixed now
   because it blocked the version fixture.

3. I changed four EXISTING tests plus a golden fixture that asserted `arca_cli 0.1.0`.
   They were pinning the defect, so changing them is correct -- but you should confirm
   I did not weaken anything. They now read VERSION at compile time; the fixture uses
   the (now working) digit pattern rather than a literal, so a release bump cannot
   falsify them. The exact-version assertion lives in one place, version_test.exs.

Ledger: `tasks.md` now carries a findings table mapping every confirmed defect to its
WP and covering AC, after hv's "do not forget A13" directive. A1-A4, A14, C2, C3 are
Done; A5-A13 and C11 are Open with homes. `intent ac status ST0011` is the one-line
check. A13 remains the thing I most want a second opinion on.

## (2026-08-04 12:30)

WP-04 and WP-05 CLAIMED DONE. Gates 4/4 and 4/4; contract now 20/40 -- halfway.
622 tests green (was 493 at ca7ba57), zero warnings, deterministic across six seeds.
Commits: 9e72412 (WP-04), 814fdfc (WP-04 test fix), 202eaa1 (WP-05).

WP-04 (A6 + A12):
- A6: `Ctx.add_output/2` now runs a `{:spinner, label, fun}`'s function at build time
  and stores the result; renderers only draw. `Output.render/1` also calls the new
  `Ctx.resolve_output/1` so a struct-literal context cannot hand a function to a
  renderer either. Plain and JSON now show the result, not just the label.
- A12 unicode: `:io.setopts(:standard_io, encoding: :unicode)`. Escript stdio defaults
  to latin1, which rendered anything above U+00FF as literal `\x{...}` text.
- A12 colour: the fix was to REMOVE the unconditional `ansi_enabled: true`, not to
  replace it. The runtime already determines at boot whether stdout is a terminal.
- `AnsiRenderer.check_tty/1` deleted; `Output.determine_style/1` is the sole authority.
  `Output.tty?/0` is public and asks `:prim_tty.isatty(:stdout)`.
- Verified on the built escript: piped = 0 ESC bytes + emoji as f0 9f 93 a6; on a real
  pty = colour present + emoji intact.

WP-05 (A5 + A7 + the cli.script leg of A13):
- A5: five copies of `try/rescue` around `GenServer.call` collapsed into one `call/3`
  using `catch :exit`. A call to a dead process exits the caller -- `rescue` never
  caught it, so the documented degradation never happened.
- History bounded (default 100, configurable). Index moved into state as `next_index`:
  derived-from-length indices start repeating once the bound is reached.
- `should_push?/1` matched its exclusion list with `=~`, so `settings.get help_url` was
  never recorded. Exact first-token match now.
- A7: new `Repl.eval_strict/3` -- exact names, no fuzzy, no history push, returns
  `{outcome, output}`. `cli.script` stops at the first failure unless `--keep-going`
  and returns an error tuple. Escript: a script containing `abut` now exits 1 instead
  of running `about`.

Four things I want you to look at specifically:

1. I changed 8 EXISTING tests across WP-04 and WP-05. Please confirm none were weakened.
   Five asserted the defect directly (three named "renders spinner with function
   execution"; two asserted a script continuing past failures and an unreadable file
   returning a display string). One compared the whole History struct and was disturbed
   by the new field. Two are the version assertions from WP-02 I already flagged.

2. My own regression, caught by hv, not by me: `io_correctness_test.exs` asserted
   `refute Output.tty?()`, which only holds when the test VM's stdout is a pipe. It
   passed for me (I always pipe) and failed for hv in a terminal. Fixed by asking the
   question in a subprocess. Worth a sweep for the same class of mistake elsewhere in
   what I have written -- I have only checked by running the suite both piped and under
   a pty, which is necessary but may not be sufficient.

3. `degradation_test.exs` was order-dependent at first: I killed the global History
   without realising it is supervised, so the supervisor raced me. Now unregisters the
   name instead. Verified across six seeds, but a second opinion on the approach is
   welcome -- unregistering produces the same `:noproc` exit, which I believe makes it
   an honest test of the real code path rather than a convenient one.

4. Latent finding, recorded on WP/09/info.md rather than fixed: lib/arca_cli.ex's
   `Mix.env() == :test && is_pid(Process.whereis(History))` branch NEVER fires. The
   application starts before test_helper.exs runs, so History is not yet registered at
   that moment and the supervisor is always started -- History IS supervised under test,
   contrary to the comment above it. Not in WP-05's scope; WP-09 owns that branch.

Next: WP-06, the largest -- A8 (dev.info crashes / dev.deps fabricates in escript),
A9 (cli.debug inert), A10 (sys.cmd triple defect, carrying the last A13 leg), A11 (Ctx
misuse), C11 (String.to_atom on user input). Ledger in tasks.md; A13's remaining legs
are AC-06.2 and AC-08.3.

## (2026-08-04 14:35)

WP-06 claimed done at 65d253a. Gate: 7/7 satisfied. Contract 20/40 -> 27/40.
683 tests green across seeds 1/42/99999, zero warnings under --warnings-as-errors,
escript rebuilt and re-probed.

Fixed: A8 (dev.info crashed / dev.deps fabricated in the escript), A9 (cli.debug
persistence inert), A10 (sys.cmd joined args, double-printed, dropped exit status),
A11 (Ctx misuse), C11 (String.to_atom on user input). Plus three catalogued as design
debt that turned out behavioural: C1 (put_lines IO.inspect at users), C4
(namespace_command returned [do: value] and generated under the wrong namespace),
C12 (subcommand argv from map key order). A13's sys.cmd leg is closed; only AC-08.3
remains.

New finding A15, added to the ledger: `sys.cmd` with no arguments crashed with a
KeyError on `e.original`, because the rescue assumed everything it caught was an
ErlangError. Same handler as A10, covered by the same rewrite, so it takes AC-06.1
rather than a new AC.

Four asks:

1. Tests changed rather than preserved, per the standing rule. Please check none was
   weakened:
   - `test/arca_cli/commands/sys_command_test.exs` DELETED, with the dead `:sys` twin
     it covered. It also asserted the tuple leak as expected behaviour, so it could
     not have survived the fix.
   - `test/arca_cli/commands/namespace_command_helper_test.exs` REWRITTEN. The old one
     hand-defined `Arca.Cli.Commands.TestTest1Command` at exactly the name the macro
     was hardcoded to generate, so the two definitions collided, and then asserted with
     `=~`, which passes just as happily on `[do: "Output from test1"]`. It could not
     see either defect. I verified both defects were real by replicating the old macro
     standalone before rewriting.
   - `test/test_helper.exs` `restore_setting(key, nil)` now removes the setting instead
     of returning `:ok`.
   - `test/arca_cli/display_regression_test.exs` gained a setup pinning `debug_mode`.

2. The test_helper change is worth a look. `restore_setting(_key, nil), do: :ok` had
   been leaking `debug_mode: true` out of cli_debug_command_test into every later test
   module. It was harmless only for as long as nothing read the setting back -- adding
   `apply_persisted_settings/1` gave it teeth and two of my own WP-01 tests went red.
   I fixed the leak AND pinned the setting in the affected test. Please check whether
   any other test relies on a setting it never restores.

3. `Arca.Cli.apply_persisted_settings/1` uses an explicit whitelist
   (`%{"debug_mode" => :debug_mode}`) rather than copying settings into application env
   wholesale. That was deliberate -- the settings file is user-editable and a blanket
   copy would let it write arbitrary app env, including `:configurators`. Second opinion
   welcome on whether the whitelist is the right shape or over-cautious.

4. Harness gotcha you will hit if you re-run the display corpus: `config/dotenv.exs`
   loads `config/.env` (gitignored), which sets `ARCA_CLI_CONFIG_PATH`. Being loaded
   during config evaluation it overrides anything exported by the shell, so config
   isolation via env var silently does not apply -- and a fresh `git worktree` has no
   `config/.env`, so it resolves a different config path than the working tree. My first
   comparison showed a spurious `settings.all` difference for exactly this reason. Both
   checkouts need the same `config/.env`. Written up in impl.md.

Separately, flagged to hv, not a code issue: `config/.env` holds what look like live
OpenAI and HuggingFace tokens plus a signing secret. Gitignored, so nothing is in
history, but it is plaintext on disk.

Next: WP-08 (one error-formatting pipeline, carrying the last A13 leg AC-08.3), then
WP-07 purge over stable code, then WP-09, then WP-10.

## (2026-08-04 14:55)

WP-08 claimed done at d0c6b2e. Gate: 3/3 satisfied. Contract 27/40 -> 30/40.
713 tests green across seeds 1/42/99999, zero warnings, escript rebuilt and
re-probed. Display re-baselined against 65d253a: 17 of 28 blocks byte-identical,
the 11 that changed all error paths, no success path moved.

A13 IS FULLY CLOSED. All three legs: cli.script (WP-05), sys.cmd (WP-06),
settings.get + cfg.get + cli.redo (WP-08, AC-08.3). The gate passing 3/3 on a WP
that names AC-08.3 is the mechanical proof. Please verify that independently --
it is the one hv asked explicitly not to be forgotten, and my own gate passing is
not the same as an outside check.

Two new findings, both covered by AC-08.1 rather than new ACs:

A16 -- the command-not-found suggestion machinery was UNREACHABLE. The
unknown-command path called handle_error/1 with `["Unknown command:"] ++ errors`,
which takes the list clause; only the string clause consults find_similar_commands.
So the "Did you mean" block and the namespace listing existed, had unit tests, and
had never fired for a user. Worth a look as a class: a feature with green unit
tests and no reachable call path is exactly what a suite cannot tell you about.
Are there others?

A17 -- Logger wrote to stdout. Same family as A12: a caller piping the CLI got log
lines mixed into the data, and the first line of a failed command was a stack trace.
Now on stderr. This one changes behaviour for downstream users who capture stdout,
so it wants an explicit changelog entry in WP-10.

Three asks:

1. 18 existing assertions changed, across error_handler_test, error_handling_test,
   display_regression_test and arca_cli_test. All pinned an old dialect. I reviewed
   each individually rather than sed-ing them; please confirm none was weakened.
   display_regression_test still pins exact text with ==, just the new text.

2. Scope call I made rather than deciding silently: the Ctx renderer path still
   presents errors its own way (a cross mark then "false exited with status 1")
   rather than in the
   `error:` dialect. My reasoning is that AC-08.1 names four string paths, and the
   renderer is a presentation layer with per-style output (ANSI, plain, JSON) where
   a JSON consumer wants a field, not a prefix. But it does mean `grep '^error:'`
   over stdout misses Ctx-reported failures. If hv wants those unified too it is a
   small change to the renderers -- flagging rather than assuming.

3. `ExUnit.start(capture_log: true)` was added because the Logger move made log
   output visible in the test run. Please check it does not hide anything you were
   relying on seeing.

Next: WP-07 (dead code purge and dep prune) over now-stable code, then WP-09
(remove test-env branching), then WP-10 (docs, changelog, 0.5.0 release).

## (2026-08-04 14:05)   FYI only -- no response needed.

Folding and compacting. cc is paused; picking up WP-09 next by hv direction (taken
ahead of WP-07, which stays queued behind it).

hv is arranging your review of what has landed, so this is a pointer to where the
evidence lives rather than a new ask. Everything already asked for stands.

State at this fold: WP-01..06 and WP-08 done, contract 30/40, 713 tests green across
seeds and verified both piped and under a pty, zero warnings under
--warnings-as-errors. Every row in the tasks.md findings ledger now reads Done -- 27
of them. The 10 unsatisfied ACs are all in WP-07, WP-09 and WP-10.

Where to look:
  - `intent/st/ST0011/tasks.md`      -- findings ledger, one row per confirmed defect,
                                        each naming its WP and covering AC
  - `intent/st/ST0011/acceptance.md` -- the AC-to-AT coverage map and live status
  - `intent/st/ST0011/impl.md`       -- AC-01.4 display re-baselines (WP-06 and WP-08),
                                        AC-01.5 halt evidence, AC-08.3 exit-code table
  - `intent/whiteboard/cc/.history/20260804/wip.md` -- per-WP archive with commit hashes

Commits: 72e9166 (WP-01), c433a60 (WP-02+03), 9e72412 + 814fdfc (WP-04), 202eaa1
(WP-05), 65d253a (WP-06), d0c6b2e (WP-08), c9f6460 (build-lock fix).

The four highest-value things to disbelieve, in my order:

1. A13. hv asked explicitly that it not be forgotten. I claim all three legs closed
   and the close-gate agrees, but my gate checking my tests is not independent.
2. The 26 changed existing assertions. Each was asserting a defect and each was
   reviewed individually rather than sed-ed, but that is my word for it.
3. A16 as a class, not an instance: a feature with green unit tests and no reachable
   call path. Is there anything else in this codebase that looks tested and is dark?
4. The Ctx renderer scope call (see my 14:55 message) -- a genuine boundary decision
   I made rather than escalated, and hv may want it the other way.
