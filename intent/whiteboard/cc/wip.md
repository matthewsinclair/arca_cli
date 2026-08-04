---
node: cc
name: Control Claude
role: control
session_id: 73036f8b-63e9-4bf1-8d44-40bf1a20a17e
heartbeat_at: 2026-08-04T12:54Z
status: active
focus: "ST0011 WP-06 command hygiene (contract 20/40)"
claims: [ST0011]
---

# Control Claude (cc)

## DOING

- ST0011 WP-06 (command hygiene) -- next up, and the largest WP. Carries A8
  (`dev.info` crashes and `dev.deps` fabricates in the escript), A9 (`cli.debug on`
  is inert), A10 (`sys.cmd` double-prints, joins args, discards OS exit status),
  A11 (Ctx consumers pass the command atom as `args`), C11 (`String.to_atom` on
  user input). AC-06.2 carries the `sys.cmd` leg of A13.

## TODO

- WP-06 -> WP-08 (carries the last A13 leg, AC-08.3) -> WP-07 purge -> WP-09 -> WP-10.
- Gates: full suite green after every WP; rebuild escript and re-run the E-probe smoke
  set after WP-06 and WP-07.
- Signal vc via `vc/inbox.cc.md` as each WP reaches claimed-done. WP-01..05 all claimed;
  vc has not yet posted verification findings for any of them.

## Watch-outs

- `handle_args/3` is shared by one-shot AND REPL paths (`repl/repl.ex`). The
  string-returning adapters over `dispatch_args/3` are what keep the REPL working --
  do not "simplify" them away.
- Test call sites must use `Arca.Cli.run/1`, never `main/1`: `main/1` halts and will
  kill the test VM mid-suite. Same for anything in `lib/arca_cli/testing/`.
- Downstream wraps `main/1` via their own escript main_module (Eg.Cli pattern, Laksa),
  so the halt must stay in `main/1` for them to inherit it from a dep bump alone.
- Renderers must not execute anything. Deferred work resolves in `Ctx.add_output/2`,
  with `Ctx.resolve_output/1` as the safety net in `Output.render/1`.
- History IS supervised under test: `lib/arca_cli.ex`'s `Mix.env() == :test` guard never
  fires, because the app starts before `test_helper.exs`. Killing History in a test races
  the supervisor -- unregister the name instead. Recorded for WP-09 on `WP/09/info.md`.
- Do not write tests that depend on whether stdout is a terminal. hv caught one of mine
  (`refute Output.tty?()`) that passed piped and failed in a real terminal. Ask such
  questions in a subprocess. Run the suite BOTH piped and under a pty before claiming.
- zsh does not word-split unquoted vars: shell repro loops need `"$@"` via a function,
  or a bash script with `read -r -a`. This has bitten me twice.
- `intent/whiteboard/vc/inbox.cc.md` shows as modified when vc clears my messages. That
  is vc's change to commit, not mine -- never `git add` another node's directory.
- Nothing is "remembered" in prose: every confirmed finding must own a row in the
  `tasks.md` findings ledger AND an AC. `intent ac status ST0011` is the one-line
  mechanical check (20/40 at this fold); the ST cannot close below 40/40.

## Decisions

- (2026-08-04) Baseline: 493 passing at ca7ba57. Now 622 passing, zero warnings under
  `--warnings-as-errors`, deterministic across six seeds.
- (2026-08-04) Audit verdict: three recurring loss archetypes -- outcomes discarded,
  config read-but-not-honoured, environment-dependent behaviour. 0.5.0 fixes the
  archetypes, not just instances. Evidence: `intent/st/ST0011/design.md`.
- (2026-08-04) hv ratified the acceptance contract and all 7 open decisions in cc's
  favour. Full table in `intent/st/ST0011/tasks.md`.
- (2026-08-04) WP-01 shape: `dispatch*` functions carry `{outcome, output}`; the
  historical `handle_*` / `parse_command_line` names survive as one-line `|> elem(1)`
  adapters. That is what let the outcome channel land under 462 existing tests and the
  REPL without touching either.
- (2026-08-04) `main/1` halts on `:error` only; `:ok` and `:warning` return normally.
  `System.halt/1` flushes IO, so no flush-safe variant was needed (probed at 50k lines).
- (2026-08-04) Recurring pattern worth naming: several fixes were REMOVALS, not
  replacements. The forced `ansi_enabled: true`, the duplicate default site in
  `config/2`, the DftConfigurator fallback. When config is "not being honoured", look
  first for a second writer of the same value.
- (2026-08-04) New findings this session: A13 (leaf commands return failure as a display
  string -> AC-08.3, AC-05.4 done, AC-06.2 pending) and A14 (fixture patterns never
  matched -> AC-09.4, done). Both are in the ledger.
- (2026-08-04) hv directive on A13: timing is cc's call, delivery is not optional.
  Guarded by the ledger, a MUST-NOT-BE-DROPPED note in `WP/08/info.md`, and the
  close-gate, which is verified to refuse WP-08 naming AC-08.3.
- (2026-08-04) vc's pre-kickoff review landed 7 findings; all accepted and applied.
  Concurred with their AC-01.4 clarification: the display corpus re-baselines at each WP
  whose ratified ACs change output, with the diff recorded in impl.md.
- (2026-08-04) Tests that assert a defect must be changed, not preserved -- but every
  such change is flagged explicitly to vc. 8 existing tests changed so far across
  WP-02/04/05, all listed in `vc/inbox.cc.md`.
