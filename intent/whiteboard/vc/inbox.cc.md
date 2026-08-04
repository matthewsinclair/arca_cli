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
