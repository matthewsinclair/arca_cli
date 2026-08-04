# cc archive -- 2026-08-04

Archived at localfold. Live board retains frontmatter, current DOING/TODO, watch-outs, and still-relevant decisions.

## DONE (archived from ## DOING)

- Session bootstrap as node cc; whiteboard picked up (sole node at the time; vc joined
  later in the session as validation, standby).

- issue 0001 (high, OPEN) -- every command exits 0. Reproduced end-to-end against the
  built escript across 8 failure modes (all exit 0). Root cause traced to three
  sequential loss points in `lib/arca_cli.ex` (:321 hardcoded `:ok`, :739 drops
  `ctx.status`, :654-667 stringifies errors). Detailed fix plan presented to hv.

- ST0011 Fable review -- full audit of `lib/` (all 55 files at ca7ba57), findings
  probe-verified (8 runtime probes, 8 escript probes; one candidate finding withdrawn
  when it passed). Catalogued as A1-A12 confirmed correctness failures, B1-B10 dead
  machinery, C1-C15 design debt. WP-01..WP-10 elaborated with deliverables + dependency
  DAG. Acceptance contract drafted. All artifacts under `intent/st/ST0011/`.

- hv review completed 2026-08-04: acceptance contract RATIFIED, all 7 open decisions
  ruled in favour of cc's recommendations. Recorded in `intent/st/ST0011/tasks.md`.

## Superseded

- Board's earlier "(new workstream -- not yet started)" focus and empty placeholder
  sections from node scaffolding.

## DONE (archived at localfold 2, 12:30Z)

- WP-01 exit codes / issue 0001. Status-carrying `dispatch*` core with display-only
  adapters; `run/1` pure, `main/1` halts. Display proven unchanged by diffing a
  17-command corpus against a ca7ba57 worktree. 520 green. Commit 72e9166.
- Findings ledger added to `tasks.md` after hv's "do not forget A13" directive; gate
  verified to refuse WP-08 naming AC-08.3. Commit 4564eb7.
- WP-02 version truth + WP-03 configurator truthfulness. VERSION is the single source
  via the app spec; `--version` routed; `|| true` coercions killed by removing the
  duplicate default site; coordinator raises instead of substituting DftConfigurator;
  dispatch searches from the end to match Optimus's last-wins merge. Found A14 en route
  (fixture `{{\d+}}`/`{{\w+}}` patterns never matched -- Elixir escape semantics).
  544 green. Commit c433a60.
- WP-04 pure renderers. Spinner work runs once at Ctx build time; `check_tty` deleted;
  unicode via `:io.setopts`; ANSI fixed by REMOVING the forced flag. 595 green.
  Commits 9e72412, 814fdfc.
- WP-05 History and REPL integrity. Five ineffective `try/rescue` collapsed into one
  `catch :exit`; history bounded with a tracked index; exact history exclusion; strict
  script execution with stop-on-error. 622 green. Commit 202eaa1.

## Superseded

- Watch-out "~20 test call sites invoke main/1" -- done in WP-01, all 22 migrated.
- Watch-out about WP-02/WP-03 being next -- both closed.

## Archived at the second fold (2026-08-04T14:05Z) -- WP-06 and WP-08

### WP-06 Command hygiene -- Done (65d253a), gate 7/7

- `sys.cmd` rewritten to return a Ctx: arguments stay separate, output is carried
  rather than printed, OS exit status is the command's outcome. Closed the sys.cmd
  leg of A13. The dead `:sys` twin module and its test deleted.
- `dev.info` / `dev.deps` made escript-safe: no Mix at runtime, real loaded
  applications instead of a hardcoded dependency list. `arca_config` had been
  missing from the fabricated list entirely.
- `cli.debug` persistence made real via `Arca.Cli.apply_persisted_settings/1`,
  an explicit whitelist applied at the start of every invocation.
- One command-name resolver (`Help.to_command_atom/1`) answering from the
  registered commands; one style parser (`Ctx.parse_style/1`). Four
  `String.to_atom` sites on user input gone.
- `Ctx.for_command/4` added, `Ctx.new/3` raises on an atom in the args position,
  three in-repo misusers fixed.
- C1 (put_lines IO.inspect), C4 (namespace_command), C12 (subcommand argv order)
  all turned out behavioural despite being catalogued as design debt.
- A15 found: `sys.cmd` with no arguments crashed with a KeyError.

### WP-08 One error-formatting pipeline -- Done (d0c6b2e), gate 3/3

- Four dialects collapsed to one: `error: <context>: <message>`, produced only by
  `ErrorHandler.format_error/2`. `format_error_with_type` and
  `error_type_to_prefix` deleted; the REPL's deprecated formatter deleted.
- Reasons rendered as text, not inspected -- no more `"Key not found"` with quotes.
- **A13 fully closed.** `settings.get`, `cfg.get`, `cli.redo` now return error
  tuples. With WP-05's `cli.script` and WP-06's `sys.cmd`, every leg is done.
- A16 found: the command-not-found suggestion machinery was unreachable. It had
  green unit tests and had never fired for a user.
- A17 found: Logger wrote to stdout, so a piped CLI mixed diagnostics into data.
  Now on stderr; `ExUnit.start(capture_log: true)` keeps the test run quiet.
- 18 existing assertions changed, each reviewed individually, all flagged to vc.

### Build-lock fix (c9f6460)

24 subprocess tests spawned `mix run` and re-verified a build the parent had just
compiled, contending for the global build lock. `--no-compile --no-deps-check`
takes steady-state contention to zero, measured over three piped and four pty runs.

## Superseded at the second fold

- Watch-out "WP-06 is next and the largest" -- done.
- Watch-out about A13's remaining legs -- all three closed; the ledger row reads Done.

---

# Archive: ST0011 complete (2026-08-04, 17:25Z)

Contract 40/40 PASS. All ten WPs Done. Issue 0001 CLOSED. Suite 493 -> 710.

## Commits

| Commit    | What                                                    |
| --------- | ------------------------------------------------------- |
| `65d253a` | WP-06 command hygiene                                   |
| `d0c6b2e` | WP-08 one error-formatting pipeline                     |
| `c9f6460` | build-lock fix (introduced A23; corrected in WP-09)      |
| `6825f05` | localfold                                               |
| `f64227f` | WP-09 remove test-env branching                         |
| `4b1dbd5` | WP-07 dead code purge and dependency prune              |
| `f4400a4` | WP-10 docs, changelog, 0.5.0                            |

## Per-WP execution notes (superseded by intent/st/ST0011/impl.md)

WP-09 handoff measurements, the 12 environment-branching sites and their
disposition, the WP-07 batch table, and the E1-E8 re-run all live in
`intent/st/ST0011/impl.md` and `tasks.md` now. They were on the live board while
in flight; the steel thread is where they belong permanently.

## Watch-outs retired with the work

- The WP-09 site list (`arca_cli.ex:148/190/377/...`): all removed, guarded now by
  `test/arca_cli/no_test_env_gate_test.exs`.
- "History IS supervised under test, the guard never fires" -- the guard is gone.
- "Re-baseline the display corpus per WP" -- no more WPs.
- "The ST cannot close below 40/40" -- it is at 40/40.
