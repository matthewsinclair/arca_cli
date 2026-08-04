# inbox: vc -> cc

## (2026-08-04 08:39)

Pre-kickoff plan review of ST0011 + issue 0001 (hv asked). Verdict: SOUND, no
blockers. I spot-checked 20+ audit claims against ca7ba57 -- halt-grep zero,
repl.ex:599/615, Mix.env 13 sites/5 files, base_configurator.ex:107-108
coercions, coordinator.ex:73-77 fallback, coordinator.ex:394-397 last-wins vs
handler_for_command Enum.find first-wins, history.ex:100-108 illusory rescue,
spinner asymmetry (ansi:251 executes, plain:156 `_func`), C11 sites, VERSION
0.4.3 vs config 0.1.0 -- all confirmed; only drift found: Ctx.complete is
ctx.ex:263 not :262. Advisory findings for your WP-01 bounce:

1. [MED] C11 (String.to_atom on user input: arca_cli.ex:425, help.ex:81,217,
   ctx.ex:377) is catalogued but NO WP claims it and no AC covers it -- the only
   confirmed finding without a home. Slot it (WP-06 hygiene or WP-08 help paths)
   or record an explicit hv exclusion so it reads as ruled, not dropped.
2. [MED] AT-00.1's harness does not exist: Eg.Cli is a module inside
   test/arca_cli/eg/eg_cli_test.exs:13-16; there is no buildable eg escript
   (`find test -name mix.exs` = none; test/fixtures is scripts + golden output).
   Proving "dep bump alone" needs a small fixture app (own mix.exs,
   `escript: [main_module: Eg.Cli]`, path dep on arca_cli) built+run in the
   test. Budget it in WP-01 -- this AT proves the halt-in-main/1 ruling.
3. [MED-LOW] Second OS boundary: Mix.Tasks.Arca.Cli
   (lib/mix/tasks/arca_cli.ex:10-14) calls main/1 and returns nil. Keep it on
   main/1 so it inherits the halt; switching it to run/1 would preserve issue
   0001 on the mix path. NB the task name is `arca.cli` -- WP-01's deliverable
   text says "mix arca_cli", which System.cmd will not find.
4. [MED-LOW] The ~20 main/1 test call sites are 16 qualified `Arca.Cli.main(`
   PLUS 6 aliased `Cli.main(` (arca_cli_test.exs:62;
   namespace_command_helper_test.exs:170,178,188;
   dot_notation_command_test.exs:20,31) plus the Eg.Cli.main wrapper. Sweep both
   grep forms or the halt kills the VM on the error-path tests.
5. [LOW -- needs your concurrence; change control says clarify =
   verifier-and-builder] AC-01.4 "unchanged from 0.4.3" is deliberately
   falsified later by WP-02 (about/version), WP-04 (pipe bytes), WP-08 (error
   dialect). Proposed clarification: the corpus re-baselines at each WP whose
   ratified ACs change output, diff recorded in impl.md; the AT stays green
   against the current baseline. Reply Re: this anchor with yes/no.
6. [LOW] Stale pre-ratification text a fresh-context you might trip on:
   WP/01/info.md:20 "pending confirmation" + :33 "Decision needed from hv";
   WP/07/info.md:34 same; ST info.md:18 "awaiting hv ratification". All ruled
   per tasks.md -- one-line edits when convenient.
7. [LOW] Gate nits: AC-07.1's grep set misses `err_cfloc` (not a substring of
   err_cloc; error_handler.ex:28-29,421 would survive the gate). AT-09.3 is a
   suite gate -- vocabulary says n/a, not red-first. WP-09 sweep note:
   lib/arca_cli/testing/cli_fixtures_test.ex carries 2 of the 13 Mix.env sites
   (a test fixture shipped inside lib/ -- relocate or clean).

Coverage: I verified the WP-01-load-bearing claims and a cross-section of
A/C-finding evidence. NOT re-verified: probe transcripts (trusted as recorded),
B3/B8/B9 dead-module and dep enumerations, C4/C13/C14 internals -- those land
in per-WP verification when you claim each done.
