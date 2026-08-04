---
node: cc
name: Control Claude
role: control
session_id: 73036f8b-63e9-4bf1-8d44-40bf1a20a17e
heartbeat_at: 2026-08-04T08:30Z
status: paused
focus: "ST0011 ratified -- starting WP-01 (exit codes, issue 0001) after compact"
claims: [ST0011]
---

# Control Claude (cc)

## DOING

- ST0011 WP-01 (exit codes / issue 0001) -- next up. Audit + planning phase is archived
  to `.history/20260804/`; contract is RATIFIED and all 7 decisions ruled, so
  implementation can start without further hv input.

## TODO

Execution order per `intent/st/ST0011/tasks.md`:

- WP-01 exit codes -> WP-02 + WP-03 (parallel) -> WP-04/05/06 (parallel) -> WP-08 ->
  WP-07 purge -> WP-09 test-env purge -> WP-10 docs + 0.5.0 release.
- Gates: full suite green after every WP; rebuild escript and re-run the E-probe smoke
  set after WP-01, WP-04, WP-06, WP-07.
- Signal vc via `vc/inbox.cc.md` as each WP reaches claimed-done (they are on standby to
  verify).

## Watch-outs

- `handle_args/3` is shared by one-shot AND REPL paths (`repl/repl.ex:599,615`) -- keep
  string-returning adapters when adding the status pipeline (WP-01).
- ~20 test call sites invoke `Arca.Cli.main/1` under capture_io; migrate to `run/1`
  BEFORE `main/1` gains System.halt or the suite kills its own VM (WP-01).
- Downstream wraps `main/1` via their own escript main_module (Eg.Cli pattern, Laksa) --
  halt must live in `main/1` so downstream inherits by dep bump alone.
- The suite currently leans on lib's Mix.env branches; WP-09 rework is the riskiest --
  don't fold it into other WPs opportunistically.
- zsh does not word-split unquoted vars: escript repro loops need `"$@"` via a function,
  or results are misleading (bit me once during the audit).

## Decisions

- (2026-08-04) Baseline: 493 passing (31 doctests, 462 tests), 0 failures, no compile
  warnings, at ca7ba57. Any regression is measured against this.
- (2026-08-04) Audit verdict: three recurring loss archetypes -- outcomes discarded,
  config read-but-not-honoured, environment-dependent behaviour. 0.5.0 fixes the
  archetypes, not just instances. Evidence: `intent/st/ST0011/design.md`.
- (2026-08-04) hv ratified the ST0011 acceptance contract and all 7 open decisions in
  cc's favour: warning -> exit 0; single failure code 1; last-registered-wins for
  duplicate commands; delete REPL_MODE; delete (not deprecate) legacy public modules
  with a changelog map; WP-09 stays in 0.5.0; error dialect
  `error: <context>: <message>`. Full table in `intent/st/ST0011/tasks.md`.
