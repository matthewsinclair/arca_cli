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

---

# Fold 2 -- after WP-11 (2026-08-04, ~17:00Z)

The first fold above closed the thread at 40/40 with ten WPs. It reopened: hv ruled
all remaining fixes into 0.5.0, so WP-11 landed the closing batch and the contract
is now 44/44 with eleven WPs. This section archives WP-11's execution record.

## WP-11 commits

| commit    | what                                                              |
| --------- | ----------------------------------------------------------------- |
| `5bdebe4` | A18/A19/A20/A24 + Ctx renderer dialect + A25 + width pins + changelog block |
| `570d90e` | first claim to vc                                                 |
| `1ed8bbb` | A26 (inert A24 fix) + A27 (second Ctx failure channel) after vc's NOT PASS |
| `faa5917` | re-claim to vc                                                    |
| `9f5a55b` | board correction on arca_config ownership                         |

## The two rounds, and why there were two

Round one fixed the four A13-class paths, implemented hv's renderer ruling, pinned
the renderer widths and wrote the changelog block. 728 green, gate 4/4, contract
44/44, claimed.

vc returned **NOT PASS** on one HIGH: A24's fix was inert. `handle/3` returned the
right tuple from a branch nothing could execute, because `flush_command_history/0`
discarded `History.flush_history/0`'s return value one level down. The construct
gate passed throughout -- it could prove the old display string was gone and never
that the new tuple was reachable. vc also found the `^error:` invariant covered only
one of the Ctx's two failure channels, and that the AC-07.2 hv ack was untranscribed.

Round two fixed both, added the reachability test through vc's seam, replaced the
per-channel assertions with a channel x style cross-product, and proved that
cross-product discriminates by breaking the guard and watching exactly the right
rows go red. 736 green.

## Superseded watch-outs, retired here

- "hv ruling: does the A13 residue join 0.5.0?" -- ruled in; A18/A19/A20/A24 done.
- "hv ruling: the Ctx-renderer error dialect" -- ruled "both"; done, and it turned
  out one of the two text renderers was rendering errors not at all (A25).
- "vc's N2, unhomed" -- homed in WP-11 and widened past the file vc named; the
  suite is green at 40/60/100/200 columns.
- "cc moves to ../arca_config ST0002" -- true for about ten minutes. hv brought cc
  back for the closing batch and gave ST0002 to a separate cc session with its own
  node and session_id. vc flagged this board as stale on it; corrected in `9f5a55b`.
- "A24 is the only OPEN ledger row" -- closed. The ledger has no OPEN rows.

## Findings numbered in WP-11

A18, A19, A20 (vc's reserved N1 trio), A24 (cc, WP-07), A25 (cc, implementing the
renderer ruling), A26 and A27 (vc, re-verifying WP-11), C13 (release trap, at vc's
request so it survives to the next release).

---

# Fold 3 -- WP-12, WP-13, WP-14, and the bump arriving

## Commits

| commit    | what                                                        |
| --------- | ----------------------------------------------------------- |
| `c85fc2f` | WP-12: one predicate decides whether a Ctx failed (A28)     |
| `24b0168` | claim WP-12 to vc, archive the A28 report                   |
| `988b5fb` | record the release gate -- arca_config blocks sign-off      |
| `25fdcd7` | WP-13: the config load diagnosis survives to the user (A29) |
| `dacdcaa` | WP-14: pin the arca_config contract (A30, A31)              |
| `7afd7f7` | relay hv's ruling that arca_notionex is out of scope        |
| `406b734` | close the branch-dep concern -- I had it wrong              |

ST0011 moved 44/44 -> 54/54, eleven WPs -> fourteen, 736 green -> 780.

## The four findings, all after the thread was "finished"

- **A28** (vc, MED against its own PASS): the dialect line was gated on status for
  one failure channel and not the other. The filed frame was "which status gates
  the line"; the actual defect was that FOUR sites answered "did this ctx fail"
  independently and two disagreed with the exit code. `add_error |> complete(:ok)`
  exited 0 while printing `error:` -- A13 inverted. `add_error` with no complete
  exited 1 with no JSON status key at all, which was outside vc's matrix.
  Fixed by one authority: `Ctx.outcome/1` + `Ctx.failed?/1`.
- **A29** (vc, from a cross-repo probe): `cfg.list` strict-matched the `:ok` tuple,
  so an error tuple raised into a bare rescue that logged the raw struct and
  returned the constant "Unknown error loading settings", while `settings.all`
  reported the reason correctly off the same call. Filed as dormant-until-the-bump;
  it was live on the pinned dep via a corrupt config rather than a missing one.
- **A30**: `load_settings/0` reached past the arca_config facade to
  `Server.reload/0`, on the path for every command, on a branch-tracked dep where
  nothing resolves at compile time.
- **A31**: a shipped `@moduledoc` told readers to call a function absent from the
  pinned dep. I first read it as a live crash; it is inside the moduledoc.

## The bump arrived at the end of the day

hv updated the dep. `mix.lock` moved `8b30615` -> `03969fa` (arca_config 0.3.0,
ST0002 complete). Left UNCOMMITTED deliberately: hv then said to wait for the
final push and rebuild from head, and committing a lock that turns the suite red
would put main in a failing state.

Compile is clean with `--warnings-as-errors` -- **no API breaks**, and the WP-14
contract test did not fire, which is the right kind of silence. Suite 778/780.

Two deltas, different in kind:

| failure                              | cause                                                     | verdict           |
| ------------------------------------ | --------------------------------------------------------- | ----------------- |
| fresh install starts with debug off  | arca_config WP-04: no config now errors `:enoent` rather than falling back silently. Command still correct, exit 0; a warning line is simply present now. | test needs updating |
| `settings.get nosuchkey`             | arca_config now returns structured tuples; output reads `cannot read setting nosuchkey: {:config, :not_found, ["nosuchkey"]}` | **real defect** -- raw tuple in user-facing text, `arca_cli.ex:1110/1115` |

The second is the D5 class in a new costume, and it is the shape to watch across
the whole bump: arca_config's error values changed from strings to tuples, and
anywhere arca_cli interpolates a reason straight into a message will now print
Elixir at a user. `reason_text/1` (WP-13) already handles it for
`load_settings/0`; `setting_error/2` does not.

## Superseded watch-outs

- The `register_change_callback/2` tripwire is no longer prose: pinned twice in
  `config_contract_test.exs` (that it exists, and that `config_available?/0` still
  probes what the test names).
- The branch-dep-under-tag concern was wrong and is closed: `mix.lock` is tracked,
  so the tag ships the lock and pins a SHA.
- arca_notionex: hv ruled it out of scope. Nothing uses it, and its lock pins a
  fixed SHA so our release cannot reach it.
