---
node: cc
name: Control Claude
role: control
session_id: 73036f8b-63e9-4bf1-8d44-40bf1a20a17e
heartbeat_at: 2026-08-04T10:40Z
status: active
focus: "ST0011 WP-01/02/03 done and claimed to vc; WP-04/05/06 next"
claims: [ST0011]
---

# Control Claude (cc)

## DOING

- ST0011 WP-01, WP-02, WP-03 -- ALL COMPLETE, gates PASS, claimed to vc for
  verification. 544 tests green (was 493), zero warnings. Contract at 12/40.
  Evidence tables in `intent/st/ST0011/impl.md`.

## TODO

Execution order per `intent/st/ST0011/tasks.md`:

- Next: WP-04 (pure renderers) / WP-05 (History + REPL) / WP-06 (command hygiene) --
  parallel-safe. WP-06 is the biggest (A8, A9, A10, A11, C11 all land there).
- Then WP-08 -> WP-07 purge -> WP-09 -> WP-10 docs + release.
- Gates: full suite green after every WP; rebuild escript and re-run the E-probe smoke
  set after WP-04, WP-06, WP-07.
- Signal vc via `vc/inbox.cc.md` as each WP reaches claimed-done.

## Watch-outs

- `handle_args/3` is shared by one-shot AND REPL paths (`repl/repl.ex:599,615`). The
  string-returning adapters over `dispatch_args/3` are what keep the REPL working --
  do not "simplify" them away.
- Test call sites must use `Arca.Cli.run/1`, never `main/1`: `main/1` halts and will
  kill the test VM mid-suite. Same for anything in `lib/arca_cli/testing/`.
- Downstream wraps `main/1` via their own escript main_module (Eg.Cli pattern, Laksa),
  so the halt must stay in `main/1` for them to inherit it from a dep bump alone.
- The suite still leans on lib's Mix.env branches; WP-09 is the riskiest -- don't fold
  it into other WPs opportunistically. WP-01 deliberately preserved `main/1`'s test-only
  display branch (moved intact into `display_response/1`) rather than merging it.
- zsh does not word-split unquoted vars: shell repro loops need `"$@"` via a function,
  or a bash script with `read -r -a`. This bit me twice now -- once during the audit,
  once building the WP-01 display corpus harness.
- `intent/whiteboard/vc/inbox.cc.md` shows as modified when vc clears my messages. That
  is vc's change to commit, not mine -- never `git add` another node's directory.
- Nothing is "remembered" in prose: every confirmed finding must own a row in the
  `tasks.md` findings ledger AND an AC. `intent ac status ST0011` is the one-line
  mechanical check (6/39 satisfied as at WP-01 close); the ST cannot close below 39/39.

## Decisions

- (2026-08-04) Baseline: 493 passing (31 doctests, 462 tests), 0 failures, no compile
  warnings, at ca7ba57. Post-WP-01: 520 passing (31 doctests, 489 tests).
- (2026-08-04) Audit verdict: three recurring loss archetypes -- outcomes discarded,
  config read-but-not-honoured, environment-dependent behaviour. 0.5.0 fixes the
  archetypes, not just instances. Evidence: `intent/st/ST0011/design.md`.
- (2026-08-04) hv ratified the ST0011 acceptance contract and all 7 open decisions in
  cc's favour: warning -> exit 0; single failure code 1; last-registered-wins for
  duplicate commands; delete REPL_MODE; delete (not deprecate) legacy public modules
  with a changelog map; WP-09 stays in 0.5.0; error dialect
  `error: <context>: <message>`. Full table in `intent/st/ST0011/tasks.md`.
- (2026-08-04) WP-01 shape: `dispatch*` functions carry `{outcome, output}`; the
  historical `handle_*` / `parse_command_line` names survive as one-line `|> elem(1)`
  adapters. That is what let the outcome channel land under 462 existing tests and the
  REPL without touching either.
- (2026-08-04) `main/1` halts on `:error` only; `:ok` and `:warning` return normally so
  the escript exits 0 through normal shutdown and embedders see no behaviour change.
  `System.halt/1` flushes IO, so no flush-safe variant was needed (probed at 50k lines).
- (2026-08-04) New finding A13 (outcome never created at the leaf, vs A1's outcome
  destroyed in transit). Assigned to AC-08.3 rather than fixed in WP-01, because the fix
  changes error text and WP-08 is where the ratified dialect lands -- display changes
  once, not twice. hv ruled: timing is cc's call, delivery is not optional ("as long as
  it is fixed, then I don't mind when. Just do not forget it"). Guarded three ways: the
  findings ledger in `tasks.md`, a MUST-NOT-BE-DROPPED note in `WP/08/info.md`, and the
  `intent wp done` close-gate, which is verified to refuse WP-08 naming AC-08.3.
- (2026-08-04) vc's pre-kickoff review landed 7 findings; all accepted and applied.
  Concurred with their AC-01.4 clarification: the display corpus re-baselines at each WP
  whose ratified ACs change output, with the diff recorded in impl.md.
- (2026-08-04) Version is sourced from VERSION via the app spec, never a config copy.
  Tests read VERSION at compile time rather than hardcoding, so a release bump cannot
  falsify them -- three tests and a golden fixture had been pinning the stale 0.1.0.
- (2026-08-04) Configurator defaults now live in ONE place (`__before_compile__`);
  `config/2` records only what was declared. Two default sites is what made an explicit
  `false` indistinguishable from unset. Unknown options now warn at compile time.
- (2026-08-04) New finding A14: the fixture framework's `{{\d+}}` and `{{\w+}}` patterns
  never matched -- the replacement keys were double-quoted, so `"\d"` was the DEL escape
  and `"\w"` dropped its backslash. Fixed with `~S`; AC-09.4 covers it. Lesson: in this
  codebase, assume a documented behaviour is untested until a test proves it fires.
