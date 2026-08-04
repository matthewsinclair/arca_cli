# Tasks - ST0011: Fable review of arca_cli base code

## Tasks

- [x] Full-codebase audit of lib/ (55 files), findings verified by probe -- see design.md
- [x] Findings catalogued: 12 confirmed correctness failures (A), 10 dead-machinery clusters (B), 15 design-debt items (C)
- [x] WP-01..WP-10 elaborated with objectives, deliverables, dependencies
- [x] Draft acceptance contract (acceptance.md) -- awaiting hv ratification
- [x] hv review: AC set ratified, all 7 open decisions ruled (2026-08-04) -- see below
- [ ] WP-01 Exit codes (issue 0001)
- [ ] WP-02 Version truth
- [ ] WP-03 Configurator truthfulness
- [ ] WP-04 Pure renderers
- [ ] WP-05 History and REPL integrity
- [ ] WP-06 Command hygiene
- [ ] WP-07 Dead code purge and dep prune
- [ ] WP-08 One error-formatting pipeline
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
