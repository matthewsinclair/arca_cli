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
- [ ] WP-07 Dead code purge and dep prune
- [x] WP-08 One error-formatting pipeline -- one dialect, one formatter; A13 fully closed; A16 and A17 found and fixed en route
- [ ] WP-09 Remove test-env branching (scope ruling: in 0.5.0 or deferred)
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

hv directive (2026-08-04) on A13: "as long as it is fixed, then I don't mind when. Just do not forget it." Timing is cc's call; delivery is not optional. **All three legs are now Done**: `cli.script` in WP-05, `sys.cmd` in WP-06, and `settings.get` / `cfg.get` / `cli.redo` in WP-08 under AC-08.3. The close-gate passed WP-08 at 3/3, which is the mechanical proof that none of them was dropped.

### Contract extension since ratification (2026-08-04, cc) -- A15 and the C-findings

Two more rows joined the ledger during WP-06, both discovered by probing rather than by reading:

- A15: `sys.cmd` with no arguments crashed with a `KeyError` on `e.original`, because the rescue assumed every error it caught was an `ErlangError`. It is the same handler A10 lives in and is covered by the same rewrite, so it takes AC-06.1 rather than a new AC. Recorded so the count of confirmed correctness failures stays honest.
- C1, C4 and C12 were catalogued as design debt, not correctness failures, so they were never given ACs. All three turned out to be behavioural: `put_lines` wrote debug representations at users, `namespace_command` returned `[do: value]` from every generated command, and subcommand argv was rebuilt from map key order. They are now covered by acceptance tests even though no AC names them, which the AT list records explicitly.

### Contract extension since ratification (2026-08-04, cc) -- A16 and A17

Two more rows joined the ledger during WP-08. Both are covered by AC-08.1 rather than by new ACs, because both are the same requirement read literally: what does the user see on the first line when something fails.

- A16: the command-not-found suggestion machinery -- `find_similar_commands/1`, the "Did you mean" block and the namespace listing -- was unreachable. The unknown-command path called `handle_error/1` with `["Unknown command:"] ++ errors`, which took the list clause and never reached the string clause that consults it. So the feature existed, was tested at the unit level, and had never once fired for a user. Routing the path through `handle_error(cmd, "unknown command", :command_not_found)` fixes the dialect and lights it up in the same change: `arca_cli sys` now lists the sys namespace, `arca_cli sys.inf` now suggests `sys.info`.
- A17: `Logger` wrote to stdout. For a CLI that is a correctness defect of the same family as A12 (pipes must carry content, not decoration): a caller piping the CLI into another program got log lines mixed into the data, and the first line of a failed command was a stack trace rather than the error message. Now configured to stderr.

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
