---
node: cc
name: Control Claude
role: control
session_id: 73036f8b-63e9-4bf1-8d44-40bf1a20a17e
heartbeat_at: 2026-08-04T15:55Z
status: active
focus: "ST0011 WP-09 done (contract 33/40); WP-07 purge next"
claims: [ST0011]
---

# Control Claude (cc)

## DOING

- ST0011 WP-07 (dead code purge and dependency prune) -- next. vc's N4 extends the
  B1-B10 purge list: the REPL autocomplete pair, the ErrorHandler conversion trio
  (orphaned by BaseCommand reimplementing its own `to_legacy_error` -- a Highlander
  violation), the Utils extras, `Output.current_style/1`, and the inverted case --
  `test/arca_cli/utils/owl_table_helper.exs` lacks the `_test.exs` suffix so ExUnit
  has never run it, over code that IS production-reachable. Rename that one first
  and see what falls out.

## TODO

- WP-07 purge -> WP-10 (docs, changelog, 0.5.0, close issue 0001).
- Gates: full suite green after every WP; rebuild escript and re-run the E-probe
  smoke set after WP-07. Re-baseline the display corpus for any WP whose ACs
  change output and record the diff in impl.md.
- Signal vc via `vc/inbox.cc.md` at each claimed-done.
- Awaiting hv rulings, do not let 0.5.0 close without them: vc's N1 trio
  (A13-class residue in `base_sub_command.ex:82-95`, `cfg_commands.ex:52-54`,
  `coordinator.ex:334-345` + :237) in or out of 0.5.0; and the Ctx-renderer error
  dialect. A18/A19/A20 are reserved for N1, which is why WP-09 took A21+.
- Carried, not done: vc's N2 narrow-terminal repro (`plain_renderer_test.exs:180`
  fails at 40 cols, Owl sizing against the test VM's terminal). Out of AC-09.x
  scope; needs a home in WP-07 or an hv call.

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
- History IS supervised under test: `lib/arca_cli.ex:148`'s `Mix.env() == :test` guard
  never fires, because the application starts before `test_helper.exs`. Killing History
  in a test races the supervisor -- unregister the name instead.
- Do not write tests that depend on whether stdout is a terminal. hv caught one of mine
  that passed piped and failed in a real terminal. Ask such questions in a subprocess.
  Run the suite BOTH piped and under a pty before claiming.
- Subprocess tests go through `test/support/cli_subprocess.ex` -- do not hand-roll
  another `System.cmd("mix", ...)`. `mix test` does NOT export MIX_ENV, so a child
  that does not pin it runs in :dev against a build the parent never compiled; with
  `--no-compile` and no `_build/dev` that is 5 failures that look like CLI defects.
  The runner also scrubs ARCA_STYLE/NO_COLOR and strips Mix's build-lock notice,
  which Mix writes to STDOUT interleaved with the child's real output.
- An assertion class that passes when the harness is broken is worse than no test:
  every `exit == 1` assertion passes when the child cannot start at all. Any
  subprocess suite needs one test that proves the child actually ran.
- `config/.env` is gitignored and sets `ARCA_CLI_CONFIG_PATH` during config
  evaluation, which overrides anything exported by the shell. So env-var config
  isolation in a harness silently does not apply, and a fresh `git worktree` (which
  has no `config/.env`) resolves a different config path than the working tree. Copy
  it across before comparing checkouts, or the diff is meaningless.
- The escript writes settings to the repo-tracked `./.arca_cli/config.json`. Probes
  that toggle settings dirty a tracked file -- run them from a scratch cwd.
- A test helper that restores nothing is a leak with a long fuse. `restore_setting(key, nil)`
  returned `:ok` without removing the setting, which was harmless only until
  something read it back. Check restore paths actually restore.
- zsh does not word-split unquoted vars, and `grep --include=*.ex` needs quoting.
  Shell repro loops need a bash script with `read -r -a`. This has bitten me twice.
- `intent/whiteboard/vc/inbox.cc.md` shows as modified when vc clears my messages. That
  is vc's change to commit, not mine -- never `git add` another node's directory.
- Nothing is "remembered" in prose: every confirmed finding must own a row in the
  `tasks.md` findings ledger AND an AC. `intent ac status ST0011` is the one-line
  mechanical check (30/40 at this fold); the ST cannot close below 40/40.

## Decisions

- (2026-08-04) Baseline: 493 passing at ca7ba57. Now 713 passing, zero warnings under
  `--warnings-as-errors`, deterministic across seeds, verified piped and under a pty.
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
  `config/2`, the DftConfigurator fallback, four of the five error formatters. When
  config is "not being honoured", look first for a second writer of the same value.
- (2026-08-04) A13 is FULLY CLOSED across three WPs: `cli.script` (WP-05, AC-05.4),
  `sys.cmd` (WP-06, AC-06.2), `settings.get`/`cfg.get`/`cli.redo` (WP-08, AC-08.3).
  hv's directive was "do not forget it"; the gate passing on a WP that names AC-08.3
  is the mechanical proof it was not.
- (2026-08-04) Every row in the findings ledger now reads Done -- 27 of them, including
  the five discovered during implementation (A13 legs, A14 fixture patterns, A15
  sys.cmd KeyError, A16 unreachable suggestions, A17 Logger on stdout). The remaining
  10 unsatisfied ACs are all in WP-07, WP-09 and WP-10.
- (2026-08-04) Scope call flagged to vc and hv, not decided silently: the Ctx renderer
  path still presents errors its own way (a cross mark then the message) rather than
  in the `error:` dialect.
  AC-08.1 names four string paths, and the renderer is a presentation layer with
  per-style output where a JSON consumer wants a field, not a prefix. But it does mean
  `grep '^error:'` misses Ctx-reported failures. Small change if hv wants it unified.
- (2026-08-04) A16 is the finding worth generalising: a feature with green unit tests
  and no reachable call path. The suite cannot tell you about that class, because the
  tests exercise the function directly. Worth asking of anything else that looks tested.
- (2026-08-04) Tests that assert a defect must be changed, not preserved -- but every
  such change is flagged explicitly to vc. 26 existing tests changed so far, listed in
  `vc/inbox.cc.md` per WP.
- (2026-08-04) Verification gap CLOSED: vc returned a PASS on WP-01..06+08 against
  the ratified contract, with its own independent evidence (713 green on two seeds
  piped and under a pty, escript probed, all 26 changed assertions judged not
  weakened, several strengthened). Five new finding groups N1-N5 came back with it.
- (2026-08-04) WP-09 done. The ordering was the whole risk: every deletion is safe
  only once the suite reads a real configuration, so making the isolation genuine
  came first. Steps 1-2 then landed with ZERO test changes, which is what turns
  "these branches never fired" into a measurement instead of a claim.
- (2026-08-04) A23 is mine, from c9f6460, and the lesson generalises past this repo:
  I made lock messages go away and read the silence as success. What it actually
  bought was children running against a build nobody had compiled. Every `exits 1`
  assertion kept passing, because a child that cannot start also exits non-zero.
  When a fix makes a symptom disappear, check what else it made disappear.
- (2026-08-04) Three findings in a row now share one shape: a feature with green
  tests and no reachable path (A16), a rule whose variable is never set (A21), an
  isolation whose variable never wins (A22). The tests were not weak in isolation;
  they answered "does this code work" when the live question was "does anything
  reach it". Worth asking of the WP-07 purge list directly.
