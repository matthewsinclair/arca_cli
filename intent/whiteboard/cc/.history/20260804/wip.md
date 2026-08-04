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
