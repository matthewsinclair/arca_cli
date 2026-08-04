# Tasks - ST0011: Fable review of arca_cli base code

## Tasks

- [x] Full-codebase audit of lib/ (55 files), findings verified by probe -- see design.md
- [x] Findings catalogued: 12 confirmed correctness failures (A), 10 dead-machinery clusters (B), 15 design-debt items (C)
- [x] WP-01..WP-10 elaborated with objectives, deliverables, dependencies
- [x] Draft acceptance contract (acceptance.md) -- awaiting hv ratification
- [x] hv review: AC set ratified, all 7 open decisions ruled (2026-08-04) -- see below
- [x] WP-01 Exit codes (issue 0001) -- 520 tests green, display proven unchanged vs ca7ba57, escript gate re-run
- [x] WP-02 Version truth -- VERSION is the single source; `--version` works; A14 found and fixed en route
- [x] WP-03 Configurator truthfulness -- explicit `false` honoured; broken configurator raises; parse and dispatch agree
- [x] WP-04 Pure renderers -- spinner work runs once at Ctx build time; one style detector; UTF-8 in pipes, ANSI only on a TTY
- [x] WP-05 History and REPL integrity -- real exit handling, bounded history, exact history exclusion, strict scripts
- [x] WP-06 Command hygiene -- sys.cmd rewritten, dev.* truthful in the escript, cli.debug persistence real, one command-name resolver, A15 found and fixed en route
- [x] WP-07 Dead code purge and dep prune -- 7 unregistered commands, the config-callback subsystem, REPL_MODE, the ErrorHandler macro and conversion surface, the Utils HTTP residue, 10 direct deps; A24 found en route
- [x] WP-08 One error-formatting pipeline -- one dialect, one formatter; A13 fully closed; A16 and A17 found and fixed en route
- [x] WP-09 Remove test-env branching -- 12 sites removed, settings on the real path, one shared subprocess runner; A21, A22, A23 found and fixed en route
- [ ] WP-10 Docs, changelog, 0.5.0 release
- [ ] Close issue 0001 with Resolutions

## Task Notes

### Ratified decisions (hv, 2026-08-04) -- all cc recommendations accepted

These are binding for implementation; the WP info files referencing "recommended" now read as ruled.

| #  | Decision                                    | Ruling                                                              | WP    |
| -- | ------------------------------------------- | -------------------------------------------------------------------- | ----- |
| 1  | `:warning` exit code                        | 0 -- warning is a success with notes                                 | WP-01 |
| 2  | Failure exit codes                          | Single code 1 for all failures; no differentiated codes              | WP-01 |
| 3  | Duplicate-command policy                    | Last-registered wins, in BOTH Optimus parse and dispatch             | WP-03 |
| 4  | REPL_MODE file logging                      | Delete; revisit file logging as its own feature if wanted            | WP-07 |
| 5  | Public legacy modules + Utils HTTP residue  | Delete, with a changelog map of replacements (0.x permits it)        | WP-07 |
| 6  | WP-09 (test-env purge) scope                | Keep in 0.5.0 while the suite is already being touched               | WP-09 |
| 7  | Error dialect                               | `error: <context>: <message>` -- lowercase, no inspect-quotes        | WP-08 |

Acceptance contract ratified at the same time: `acceptance.md` moves DRAFT -> RATIFIED. Scope changes from here need hv per that file's change-control note.

### Contract extension since ratification (2026-08-04, cc) -- for hv awareness

Re-probing the repro set after WP-01 landed surfaced finding A13: four commands still exit 0 because they return their own failure as a plain display string, which the dispatch layer can only read as success. This is the A1 archetype one layer down, and it was not visible before WP-01 removed the noise above it.

- Added AC-08.3 (`settings.get nosuchkey`, `cfg.get nosuchkey`, `cli.redo 999` exit 1). The other two legs already had homes: `cli.script` is AC-05.4, `sys.cmd` is AC-06.2.
- Placed in WP-08 rather than WP-01 because fixing it changes the error text, and WP-08 is where the ratified dialect lands -- so the display changes once, not twice. Doing it inside WP-01 would also have broken the ratified AC-01.4 (display unchanged).
- This extends coverage rather than shrinking scope, so it is taken as a builder clarification under the change-control note; flagged here and to vc for hv to overrule if wanted.

### Findings ledger -- every confirmed correctness failure and where it is fixed

The forgetting-proof check. Each A-finding must name a WP and a covering AC; an unassigned row is a dropped defect. The `intent wp done` close-gate enforces the right-hand column -- a WP cannot close while any of its ACs is unsatisfied -- so this table and the gate agree by construction.

| Finding | What breaks                                            | WP    | Covering AC       | Status |
| ------- | ------------------------------------------------------ | ----- | ----------------- | ------ |
| A1      | Every command exits 0 (outcome destroyed in transit)   | WP-01 | AC-01.1..01.5     | Done   |
| A2      | `--version` prints the help screen                     | WP-02 | AC-02.1           | Done   |
| A3      | Three version sources disagree                         | WP-02 | AC-02.2           | Done   |
| A4      | Explicit `false` config coerced to `true`              | WP-03 | AC-03.1           | Done   |
| A5      | History rescue cannot catch GenServer exits            | WP-05 | AC-05.1           | Done   |
| A6      | Spinner fun runs only in ANSI mode                     | WP-04 | AC-04.1           | Done   |
| A7      | Scripts and redo fuzzy-match typos into other commands | WP-05 | AC-05.4           | Done   |
| A8      | `dev.info` crashes, `dev.deps` fabricates in escript   | WP-06 | AC-06.3           | Done   |
| A9      | `cli.debug on` persistence inert                       | WP-06 | AC-06.4           | Done   |
| A10     | `sys.cmd` double-prints, joins args, drops exit status | WP-06 | AC-06.1, AC-06.2  | Done   |
| A11     | Ctx consumers pass the command atom as `args`          | WP-06 | AC-06.6           | Done   |
| A12     | Pipes mangle unicode and leak ANSI                     | WP-04 | AC-04.2, AC-04.3  | Done   |
| A13     | Leaf commands return failure as a display string       | WP-08 | AC-08.3           | Done   |
| A13     | ... the `cli.script` leg of the same defect            | WP-05 | AC-05.4           | Done   |
| A13     | ... the `sys.cmd` leg of the same defect               | WP-06 | AC-06.2           | Done   |
| A14     | Fixture patterns `{{\d+}}` / `{{\w+}}` never matched   | WP-09 | AC-09.4           | Done   |
| A15     | `sys.cmd` with no arguments crashed with a `KeyError`  | WP-06 | AC-06.1           | Done   |
| C1      | `put_lines` IO.inspect'd maps and tuples at the user   | WP-06 | (AT, not AC)      | Done   |
| C2      | Broken configurator silently swapped for the default   | WP-03 | AC-03.2           | Done   |
| C3      | Duplicate command resolved differently by parse/dispatch | WP-03 | AC-03.3         | Done   |
| C4      | `namespace_command` returned `[do: value]`, wrong ns   | WP-06 | AC-06.5           | Done   |
| C5      | Four error formatters, four dialects                   | WP-08 | AC-08.1           | Done   |
| C11     | `String.to_atom` on user input (unbounded atom table)  | WP-06 | AC-06.7           | Done   |
| C15     | Inspect-wrapped reasons in user-visible errors         | WP-08 | AC-08.2           | Done   |
| A16     | Command-not-found suggestions were unreachable         | WP-08 | AC-08.1           | Done   |
| A17     | Logger diagnostics written to stdout, not stderr       | WP-08 | AC-08.1           | Done   |
| C12     | Subcommand argv rebuilt from map key order             | WP-06 | (AT, not AC)      | Done   |
| C6      | 12 environment-branching sites in lib                  | WP-09 | AC-09.1           | Done   |
| A21     | `Output.test_env?` never fired -- no MIX_ENV under test | WP-09 | AC-09.1           | Done   |
| A22     | Test config isolation set a variable that never wins   | WP-09 | AC-09.3           | Done   |
| A23     | Subprocess tests ran in :dev, against no build at all  | WP-09 | AC-09.3           | Done   |
| B1-B10  | Dead machinery clusters                                | WP-07 | AC-07.1, AC-07.2  | Done   |
| C10     | mix.exs no-op keys (`mix_tasks:`, `ansi_enabled:`)     | WP-07 | AC-07.1           | Done   |
| A24     | `sys.flush` reports failure as a display string        | --    | (unassigned)      | OPEN   |

hv directive (2026-08-04) on A13: "as long as it is fixed, then I don't mind when. Just do not forget it." Timing is cc's call; delivery is not optional. **All three legs are now Done**: `cli.script` in WP-05, `sys.cmd` in WP-06, and `settings.get` / `cfg.get` / `cli.redo` in WP-08 under AC-08.3. The close-gate passed WP-08 at 3/3, which is the mechanical proof that none of them was dropped.

### Contract extension since ratification (2026-08-04, cc) -- A15 and the C-findings

Two more rows joined the ledger during WP-06, both discovered by probing rather than by reading:

- A15: `sys.cmd` with no arguments crashed with a `KeyError` on `e.original`, because the rescue assumed every error it caught was an `ErlangError`. It is the same handler A10 lives in and is covered by the same rewrite, so it takes AC-06.1 rather than a new AC. Recorded so the count of confirmed correctness failures stays honest.
- C1, C4 and C12 were catalogued as design debt, not correctness failures, so they were never given ACs. All three turned out to be behavioural: `put_lines` wrote debug representations at users, `namespace_command` returned `[do: value]` from every generated command, and subcommand argv was rebuilt from map key order. They are now covered by acceptance tests even though no AC names them, which the AT list records explicitly.

### Contract extension since ratification (2026-08-04, cc) -- A16 and A17

Two more rows joined the ledger during WP-08. Both are covered by AC-08.1 rather than by new ACs, because both are the same requirement read literally: what does the user see on the first line when something fails.

- A16: the command-not-found suggestion machinery -- `find_similar_commands/1`, the "Did you mean" block and the namespace listing -- was unreachable. The unknown-command path called `handle_error/1` with `["Unknown command:"] ++ errors`, which took the list clause and never reached the string clause that consults it. So the feature existed, was tested at the unit level, and had never once fired for a user. Routing the path through `handle_error(cmd, "unknown command", :command_not_found)` fixes the dialect and lights it up in the same change: `arca_cli sys` now lists the sys namespace, `arca_cli sys.inf` now suggests `sys.info`.
- A17: `Logger` wrote to stdout. For a CLI that is a correctness defect of the same family as A12 (pipes must carry content, not decoration): a caller piping the CLI into another program got log lines mixed into the data, and the first line of a failed command was a stack trace rather than the error message. Now configured to stderr.

### Contract extension since ratification (2026-08-04, cc) -- A21, A22, A23 and the numbering

Numbering note: vc's N1 proposed rows A18/A19/A20 for the A13-class residue trio (`base_sub_command`, `cfg_commands`, `coordinator`). Those await an hv ruling on whether they join 0.5.0, so those numbers are left reserved and WP-09's findings take A21 onward. Nothing is fixed by having consecutive numbers; something is broken by two nodes writing different meanings onto the same one.

The plan counted 13 environment-branching sites and the WP found 12, but the difference is not a miscount in either direction. One site the plan listed had already gone in an earlier WP, and one site the grep could never have found was still there: `Output.test_env?` read `MIX_ENV` with `System.get_env/1` rather than calling `Mix.env()`, so it satisfied AC-09.1's grep while being the same defect. AC-09.1 is written as a grep, and a grep is a proxy for the property, not the property.

- A21: `Output.test_env?` never fired. `mix test` does not export `MIX_ENV` into the environment, so the variable it consulted was unset in the only situation it existed for. Its unit tests passed because they set `MIX_ENV` by hand first, which is the A16 archetype exactly: the tests proved the function's logic and never asked whether anything reached it. Deleting it was behaviour-preserving, and the test that asserted it now states the property that is actually true.
- A22: the config isolation in the test suite isolated nothing. It set `ARCA_CONFIG_PATH`, but `Arca.Config.Cfg.config_pathname/0` resolves the app-specific `ARCA_CLI_CONFIG_PATH` first and `config/.env` sets it, so the generic variable never won. It also wrote its config file into a directory that does not exist and discarded the resulting `{:error, :enoent}`, and restored itself by writing back a captured environment map, which cannot remove a variable that was previously unset. Every part of it was inert, and the same block was copy-pasted into eight test files. This was harmless only while the `Mix.env() == :test` branch bypassed Arca.Config entirely -- the moment WP-09 removed that branch it would have pointed the suite at the repository's own tracked config file.
- A23: the subprocess tests ran in `:dev`, not `:test`, because a child inherits an environment variable the parent never set. With `--no-compile` and no `_build/dev` -- a fresh clone, or CI -- 5 of 16 failed. The failure was asymmetric in the worst direction: every `exits 1` assertion still passed, because a child that cannot start also exits non-zero, so those assertions could not distinguish a correctly-reported failure from a child that never ran. This one was introduced by cc in c9f6460 while fixing the build-lock contention, and the silence it bought was purchased by testing a build nobody had compiled.

A23 also produced a finding worth keeping: Mix writes its build-directory lock notice to **stdout**, so it arrives interleaved with whatever the child printed. Any test asserting exact subprocess output is therefore intermittently wrong, and on a machine fast enough to avoid lock contention it would never fail at all. The shared runner strips that one line, and only that line.

### A24 -- an OPEN row, and the only one in the ledger (2026-08-04, cc)

`Arca.Cli.Commands.SysFlushCommand.handle/3` returns its failure as a display string:

    {:error, error_type, reason} ->
      "Error: Failed to clear command history (#{error_type}): #{reason}"

That is finding A13 exactly, in a registered command that ships, and in the pre-WP-08 dialect. A failed flush prints an error and exits 0.

It is left OPEN rather than fixed on the spot because it is the same question hv is already holding: vc's N1 found three more instances of this archetype (`base_sub_command.ex:82-95`, `cfg_commands.ex:52-54`, `coordinator.ex:334-345`) and asked whether they join 0.5.0. A24 is a fourth. Fixing one quietly while three wait on a ruling would split the class across two releases and make the ledger lie about how much of A13 is actually closed.

**This matters for the release, not just for tidiness.** 0.5.0's headline is that command outcomes reach the shell. Four known commands that report failure and exit 0 is a hole in exactly that claim. The fix shape is already ratified and already used for `cfg.get` in WP-08, so the work is small; what is missing is the decision. hv rules; if the answer is yes, all four get an AC and land together.

### WP-07 as-built -- what the purge removed, and the shape it kept finding

Deletions in batches, suite green between each, so a red suite could only mean the batch just removed.

| Batch | Removed                                                                 |
| ----- | ----------------------------------------------------------------------- |
| 1     | 7 unregistered command modules + the SubCommand/OneCommand example pair |
| 2     | The config-callback subsystem: a closed loop nothing entered            |
| 3     | ErrorHandler's `__using__`, 4 location macros, 3 conversion functions   |
| 4     | REPL_MODE file logging, `:is_repl_mode`, `use OK.Pipe` (2 sites)        |
| 5     | 10 direct dependencies                                                  |
| 6     | Utils HTTP residue, the REPL autocomplete pair                          |

Two things are worth recording beyond the list.

The first is that `test/arca_cli/utils/owl_table_helper.exs` was missing the `_test.exs` suffix, so ExUnit had never run it -- over `OwlHelper`, which **is** production-reachable from `plain_renderer.ex:45`. vc called this "inverted dark": not dead code with live tests, but live code with dead tests. Renaming it added 6 passing tests, including width cases at 40, 80 and 120 columns. Those passing also localises vc's N2 narrow-terminal failure: the helper handles a narrow width correctly when given one, so the fault is `plain_renderer_test` sizing against the ambient terminal instead of pinning a width.

The second is what the deletions had in common. Almost every one was reachable from its own tests and nothing else, which is invisible to a green suite -- the tests call the function directly, so they answer "does this work" while the live question is "does anything call it". `load_config_phase/0` is the clearest case: a public function calling four private ones, with no caller anywhere, because `mix.exs` declares no `start_phases`. The whole subsystem was internally consistent and entirely unreachable. That is why the gate test asserts one cluster per test rather than one omnibus grep, and why it carries a control test: a scanner that silently matched nothing would report every invariant as satisfied.

## Dependencies

Sequencing (edges are hard dependencies, otherwise parallel-safe):

    WP-01 --> WP-02 (exit path for --version)
    WP-01 --> WP-04 (main/1 surgery overlap)
    WP-01 --> WP-05 (script stop-on-error needs status signal)
    WP-01 --> WP-06 (sys.cmd exit-status leg)
    WP-01 --> WP-08 (same dispatch else-clauses)
    WP-06 --> WP-07 (SysCommand twin deleted after sys.cmd rewrite; cli.debug loader decision)
    WP-01, WP-06 --> WP-09
    all --> WP-10

Suggested execution order: 01, then 02+03 (quick wins, parallel), then 04/05/06 (parallel), then 08, then 07 (purge over stable code), then 09, then 10.

Gates: full suite green after every WP; escript rebuilt and E-probe smoke re-run after WP-01, WP-04, WP-06, WP-07.
