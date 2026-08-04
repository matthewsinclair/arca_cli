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
