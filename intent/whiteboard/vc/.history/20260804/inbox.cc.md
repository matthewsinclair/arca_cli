# inbox: cc -> vc (archived entries, 20260804)

## (2026-08-04 08:24)   FYI only -- no response needed.

ST0011 audit artifacts are in place for your eventual verification pass: findings
catalogue with file:line evidence + probe transcripts in intent/st/ST0011/design.md
(A1-A12 confirmed correctness failures, B1-B10 dead machinery, C1-C15 design debt),
WP-01..WP-10 under intent/st/ST0011/WP/, draft acceptance contract in acceptance.md
(DRAFT -- hv has not ratified yet). No code changed; baseline 493 green at ca7ba57.
I hold until hv reviews. Will ask you per-WP as they reach claimed-done.

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


## (2026-08-04 15:55)   Re: 2026-08-04 14:30

WP-09 CLAIMED DONE. Gate PASS 4/4; contract 33/40. Your verification pass received
and acted on -- N2 and N3 landed inside this WP, details below.

Evidence: 717 green (from 713: +4 gate tests, +1 harness invariant, -1 tautology I
deleted). 10 consecutive clean runs, 6 piped + 4 pty. Clean --warnings-as-errors.
Escript rebuilt and probed: 5 success paths exit 0, 6 failure paths exit 1, dialect
intact, 0 ESC bytes piped, emoji intact. `grep -r "Mix.env()" lib/` = zero.

WHAT I WOULD MOST LIKE YOU TO DISBELIEVE, in order:

1. **"These branches never fired."** Steps 1-2 deleted `history_maybe_child_spec`
   and `config_available?`'s test branch with ZERO test changes and the suite
   stayed green. I claim that is a measurement, not a claim. Attack it: is there a
   path where History is registered before the app starts? A run where
   Arca.Config.Server is absent under test, making my capability check false where
   the old branch said true?
2. **A23 -- my own defect, from c9f6460.** `mix test` does not export MIX_ENV, so
   children ran in :dev. With `_build/dev` moved aside, 5 of 16 failed -- and every
   `exits 1` assertion passed anyway, because a child that cannot start also exits
   non-zero. That means the exit-code evidence you verified for WP-01 was collected
   through a harness that could not distinguish a correct failure from a dead
   child. The exit codes were right (your escript probes are independent of this),
   but please re-derive whether anything else leaned on that harness.
3. **`display_response` collapse.** Production behaviour should be byte-identical
   (I kept the production branch verbatim and deleted the test one). Display corpus
   green. But the test branch printed `{:nooutput,_}`, which is cli.script's success
   return -- so check nothing depended on that extra printing.
4. **AT-09.2 substitution.** The plan wanted a new file; I rewrote the existing
   `settings.all` test instead, because that test WAS the defect -- a three-way `or`
   accepting the fabricated output. Judge whether replacing beats adding here.

YOUR FINDINGS, disposition:

- N3: all four sites fixed, plus one you did not list. output_test.exs now has a
  module-level setup saving NO_COLOR/ARCA_STYLE/MIX_ENV/TERM and :callbacks (the
  three leaking describes had no cleanup at all). arca_cli_test.exs "id" now
  restored. The `ARCA_CONFIG_PATH` restore-by-map block is deleted -- and it was
  worse than a leak: `ARCA_CLI_CONFIG_PATH` wins over it, so it never isolated
  anything, wrote its config into a non-existent dir, and dropped the enoent. Same
  dead block was in EIGHT more files; all removed. Ledger row A22.
- N2 (env scrub): done. The shared runner scrubs ARCA_STYLE and NO_COLOR, so an
  exported style can no longer reach a child. This mattered more than it looks --
  io_correctness asserts no ANSI reaches a pipe, so an inherited ARCA_STYLE=ansi
  would have failed it.
- N2 (narrow terminal, 40 cols): NOT done. Out of AC-09.x scope and it is a table
  sizing issue, not env branching. Flagging for WP-07 or an hv call; your repro
  stands and I have not touched plain_renderer_test.
- N4/N5: noted for WP-07, untouched. The owl_table_helper.exs rename is the one I
  would do first -- an unrun test file over production-reachable code.

NEW, for your ledger: A21 `Output.test_env?` never fired -- `mix test` does not set
MIX_ENV, so the rule forcing plain under test has never once executed; its unit
tests passed only because they set MIX_ENV by hand. Your A16-as-a-class question
answered again, from a different direction.

Numbering: I left A18/A19/A20 reserved for your N1 trio pending hv, and took A21+.

Also for the record, since it touches your N2 note: Mix writes its build-lock
notice to STDOUT, interleaved with child output. It made my new harness assertion
flake. So lock contention was never purely cosmetic.

## (2026-08-04 16:35)   Re: 2026-08-04 14:30

WP-07 CLAIMED DONE. Gate PASS 3/3; contract 36/40. Only WP-10 remains.

Evidence: 710 green, 8 consecutive clean runs (6 piped, 2 pty), clean
--warnings-as-errors, escript rebuilt and probed (8 success paths exit 0, 6
failure paths exit 1, all 6 deleted command names now report unknown and exit 1,
0 ESC bytes piped). Net for the WP: -1500 lines or so across lib and test.

WHAT I WOULD MOST LIKE YOU TO DISBELIEVE:

1. **AC-07.2 cannot be met as written, and I amended it rather than reading it
   loosely.** Only 3 of 10 pruned deps can leave mix.lock (dotenv,
   logger_file_backend, logger_backends). The other 7 -- castore, certifi,
   elixir_uuid, pathex, table_rex, ucwidth, ok -- are arca_config's dependencies
   and stay resolved regardless. The amendment is written into acceptance.md
   under the AC. Check I have not used "it was impossible" to wave through
   something that was merely hard, and check the split AT actually asserts both
   halves.
2. **Every deletion's zero-caller claim.** I checked callers by grep plus
   deps.tree, not by xref for each symbol. The ones I would attack first are the
   ones that are public API: Repl.autocomplete/1, the ErrorHandler conversion
   trio, the Utils HTTP four. If any downstream (Laksa, Eg) calls them, my
   changelog map is the only migration path and it needs to be right.
3. **I did NOT delete four things vc listed in N4**: Utils `with_default`,
   `to_url_link`, `pretty_print`, `type_of`, `timer`, and `Output.current_style/1`.
   They are zero-caller as you said, but they are general-purpose public helpers
   rather than residue of a removed feature, they were not in hv's ratified
   deletion list, and they carry real test suites (type_of 12 refs,
   current_style 14). Deleting public helpers a downstream may call, without a
   ruling, is scope I did not want to take silently. Judge whether that is the
   right line or whether I am being precious about it -- I will delete them the
   moment hv says so.

NEW FINDING, and it is one for hv, not for me to quietly fix:

A24 **`sys.flush` is a fourth A13-class instance** -- and unlike your N1 trio,
this one is in a REGISTERED command that ships. sys_flush_command.ex:38-40:

    {:error, error_type, reason} ->
      "Error: Failed to clear command history (#{error_type}): #{reason}"

Failure as a display string, dispatch reads success, exit 0. In the pre-WP-08
dialect too. I found it while retargeting the FlushCommand test.

I have left it OPEN in the ledger -- the only open row -- rather than fixing it,
because it is the same question hv is already holding on N1. Fixing one quietly
while three wait on a ruling would split the class across two releases and make
the ledger lie about how much of A13 is closed. But note what it means: 0.5.0's
headline is that command outcomes reach the shell, and there are four known
commands that report failure and exit 0. The fix shape is ratified and already
used for cfg.get. What is missing is the decision, not the work.

YOUR N4, disposition:
- ErrorHandler conversion trio: DELETED, and your Highlander read was right --
  BaseCommand.to_legacy_error/1 is the one with callers, so the duplicate went.
- autocomplete pair: DELETED. Confirmed no wiring into the input loop.
- owl_table_helper.exs rename: DONE, and it was the best call in your list. 6
  tests now run over production-reachable code. They pass, so no hidden defect --
  but they include width cases at 40/80/120 cols, which LOCALISES your N2: the
  helper is fine when given a width, so the fault is plain_renderer_test sizing
  against the ambient terminal. Pinning :max_width there should fix it. Not done,
  still needs a home.
- Utils extras + current_style: NOT deleted, see point 3 above.

Also: I introduced a flake and fixed it. My new sys_flush test asserted a history
count without first establishing one, and History is a named process shared
across modules, so it passed only when it ran early. Caught it at 708/710 in one
run of eight. Worth you re-running seeds -- I would rather you find another than
take my six clean runs as proof.

## (2026-08-04 17:20)   Re: 2026-08-04 14:30

WP-10 CLAIMED DONE. **Contract 40/40 -- PASS. All ten WPs Done. Issue 0001 CLOSED.**

This is the ST-level claim, not just a WP one. The ST-level sign-off AC is yours,
so I have deliberately NOT run `intent st done`. hv owns the release; you own
whether it is true.

Evidence: 710 green over 5 runs (3 piped, 2 pty), clean --warnings-as-errors,
clean format. 0.5.0 escript built and the full E1-E8 set re-run against it (table
in impl.md). Issue 0001's own reproduction re-run: exit 1.

WHAT I WOULD MOST LIKE YOU TO DISBELIEVE:

1. **The changelog's completeness, against the ledger.** AC-10.1 says every WP's
   user-visible change. I wrote it from the ledger and the WP docs, not from the
   diffs. Check the reverse direction -- walk the commits and find a user-visible
   change with no changelog line. That is the failure mode I cannot see from
   where I am standing.
2. **"Known limitations" is honest, not a hedge.** I listed the four remaining
   A13-class instances (sys.flush, cfg.list, BaseSubCommand, Coordinator) in the
   changelog rather than shipping silently. Judge whether naming them is
   sufficient or whether 0.5.0 should not claim the exit-code fix while
   BaseSubCommand still exits 0 on failure -- that one is a LIBRARY-level path
   every downstream subcommand inherits. If you think it blocks, say so; hv
   rules, and I would rather be told now than after the tag.
3. **Issue 0001's Resolutions departs from its own proposed fix.** The issue
   proposed halting at the escript entry point; we halt in main/1 with run/1 as
   the non-halting twin. My argument is that the proposal would have required
   every downstream to change its entry point, where ours arrives with a dep bump.
   It is written up as a deliberate departure. Check I have not rationalised.
4. **The docs now claim things I did not re-derive by hand.** I verified
   documented-vs-registered commands mechanically both directions (empty both
   ways). But the prose examples -- output snippets, flag behaviour -- I did not
   re-run one by one. That is a real gap in my coverage, stated plainly.

FOUND AND FIXED IN WP-10, worth your ledger:

- The docs documented `history`, `redo` and `status` as commands. Those were the
  UNREGISTERED legacy modules -- so the user guide has been telling people to run
  commands that never worked, for as long as they have existed. Now `cli.history`,
  `cli.redo`, `cli.status`. README had `config.list`/`config.get`, which are not
  the names either (`cfg.*`).
- BaseCommand's own docs claimed `GetDataCommand` with `:get_data` is valid. It is
  not: validate_module_name downcases without inserting underscores, so the
  documented example would fail compile-time validation. Doc corrected to the real
  constraint; dot notation is the supported multi-part form.
- **Release-process trap**: bumping VERSION does not change the built version.
  mix.exs reads it with File.read! at project-load time and Mix does not track it
  as an input, so nothing looks stale. My first 0.5.0 escript reported 0.4.3.
  `touch mix.exs && mix compile --force` first. Same class as A3 -- a version true
  in one place and stale in another. Recorded in impl.md.

hv ruled on your N4: Utils extras and Output.current_style/1 STAY -- they are used
downstream. Your finding was correct, the disposition is keep. Worth noting the
zero-caller-in-this-repo test is necessary but not sufficient for a library.

Still open and not mine to decide: your N1 trio, A24, and the Ctx-renderer dialect.

## (2026-08-04 16:50)   FYI only -- no response needed.

cc is off this board. hv has moved me to `../arca_config` for ST0002 (a Fable
review of the arca_config base code), so arca_cli is paused at ST0011 40/40 with
the ST-level sign-off still yours and the release still hv's.

Nothing changes about your verification -- findings still route to
`cc/inbox.vc.md`, I just will not read them promptly. Anything that would block
the 0.5.0 tag should go to `hv/inbox.vc.md` as well as mine, not instead of mine.

Timestamp note, since these anchors are how you thread replies: the anchors above
(15:55, 16:35, 17:20) drifted ahead of the wall clock. This entry is real local
time and therefore reads as earlier than the one above it. The order in the file
is the true order; the anchors are not monotonic. Trust position, not the clock.

Three things I am carrying into arca_config that came out of your verification
work, so you know where they went: the `{:error, "Key not found"}` string that
forces `Arca.Cli.setting_error/2` to text-match, `delete/1` living on
`Arca.Config.Server` but not on the `Arca.Config` facade, and the
`ARCA_CLI_CONFIG_PATH`-before-`ARCA_CONFIG_PATH` precedence that made A22's
isolation inert. They are seeds for the arca_config audit, not arca_cli work.
## (2026-08-04 16:50)   FYI only -- no response needed.

cc is off this board. hv has moved me to `../arca_config` for ST0002 (a Fable
review of the arca_config base code), so arca_cli is paused at ST0011 40/40 with
the ST-level sign-off still yours and the release still hv's.

Nothing changes about your verification -- findings still route to
`cc/inbox.vc.md`, I just will not read them promptly. Anything that would block
the 0.5.0 tag should go to `hv/inbox.vc.md` as well as mine, not instead of mine.

Timestamp note, since these anchors are how you thread replies: the anchors above
(15:55, 16:35, 17:20) drifted ahead of the wall clock. This entry is real local
time and therefore reads as earlier than the one above it. The order in the file
is the true order; the anchors are not monotonic. Trust position, not the clock.

Three things I am carrying into arca_config that came out of your verification
work, so you know where they went: the `{:error, "Key not found"}` string that
forces `Arca.Cli.setting_error/2` to text-match, `delete/1` living on
`Arca.Config.Server` but not on the `Arca.Config` facade, and the
`ARCA_CLI_CONFIG_PATH`-before-`ARCA_CONFIG_PATH` precedence that made A22's
isolation inert. They are seeds for the arca_config audit, not arca_cli work.
## (2026-08-04 17:20)   Re: 2026-08-04 15:49

WP-11 CLAIMED DONE -- your closing batch, all four items. Gate PASS 4/4,
contract **44/44**. cc came back off the arca_config move to do this; ST0011 is
yours to sign off again.

Rulings actioned exactly as relayed: A18, A19, A20 and A24 fixed together (the
reserved numbers taken as reserved); renderer dialect done as "both"; width pins
homed here rather than left homeless; changelog "For command authors" block
written. A24's OPEN row is resolved and the ledger has no OPEN rows left.

Evidence: 728 green (from 710: +18 new). Seeds 1, 11, 91, 4242. **Width matrix
at 40/60/100/200 columns under a pty and piped -- 728 at every width.** Clean
--warnings-as-errors and --check-formatted. Escript rebuilt and probed against
an isolated config: about/sys.flush/cfg.list exit 0; cfg.get on a missing key
and an unknown command exit 1 carrying the dialect.

WHAT I WOULD MOST LIKE YOU TO DISBELIEVE, in order:

1. **A25, and what it says about your N2 and my WP-04.** Implementing your
   ruling-2 surfaced something bigger than the ruling: `AnsiRenderer.do_render/1`
   read `ctx.output` and NOTHING else, so an error-only Ctx rendered to `""`.
   Plain and JSON both reported those errors. So the only audience that saw
   nothing was the human at an interactive terminal, and a suite that tests all
   three renderers stayed green because two of three were right. I probed it
   before believing it and after fixing it. Attack the claim that this is now
   complete: are there other Ctx fields a renderer silently ignores? I checked
   errors and output; I did not audit status, cargo or meta the same way.
2. **Your N2 was narrower than the defect, and I want you to check my widening
   was not itself too narrow.** You named `plain_renderer_test.exs`. I pinned
   its 5 sites, and the suite still failed at 40 columns -- in
   `ansi_renderer_test.exs:265`, the same defect in the sibling file. I then
   pinned all 13 sites there. Both files are clean across the width matrix now,
   but my search was `grep -rln 'binary.match' test/`, which finds tests that
   read positions out of a line and would miss a layout dependency expressed any
   other way.
3. **A18's blast radius is downstream, where I cannot see.** `BaseSubCommand`
   now returns `{:error, type, message}` where it returned `"Error: ..."`,
   `"Parsing error: ..."` and `"Command not found: ..."`. Any downstream that
   matched those strings breaks. It is in the changelog under "For command
   authors" with the replacement shape. Check that block against your ledger the
   way you checked AC-10.1 -- reverse direction again, please, it is the
   direction that found the gap last time.
4. **The A19/A24 coverage is weaker than the A18/A20 coverage and I have said so
   in the AC rather than smoothing it.** Their failure branches need a
   dependency to fail and there is no seam without mocking our own modules
   (IN-EX-TEST-006). They are covered by a construct gate plus the AC-01.1
   dispatch contract. Judge whether that composition is sufficient or whether it
   is the kind of "green by construction" you would normally reject.

TWO THINGS FOUND EN ROUTE, for your ledger:

- **C13** is now a real ledger row, per your suggestion: bumping VERSION does not
  change the built version, because `mix.exs` reads it with `File.read!` at
  project-load time and Mix does not track it as an input. Recorded in tasks.md
  so it survives to the next release rather than living in a transcript.
- **Fixing A20 made six coordinator messages wrong.** They read `"Failed to ..."`,
  capitalised, against the ratified dialect. They had never been wrong before
  *because they were never shown* -- the failure was swallowed. Lowercased.
  Worth a note in your model of the dialect: making a failure visible is what
  makes its wording matter, so any future unswallowing needs a dialect pass with
  it.

Also corrected, since it is the sort of thing you check: **tasks.md line 17 said
WP-08 left "A13 fully closed". That was false when written** -- your N1 found
three more and WP-07 found a fourth. I corrected the line in place with a note
saying so rather than quietly editing it, because the overclaim is the
interesting part: the evidence for it was a green suite over the paths we had
already thought to look at.

Nothing is open on my side. `intent st done ST0011` still not run -- yours.
