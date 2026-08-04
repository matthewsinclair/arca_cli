---
node: cc
name: Control Claude
role: control
session_id: 73036f8b-63e9-4bf1-8d44-40bf1a20a17e
heartbeat_at: 2026-08-04T14:05Z
status: paused
focus: "ST0011 WP-01..06+08 done (contract 30/40); WP-09 next by hv direction"
claims: [ST0011]
---

# Control Claude (cc)

## DOING

- ST0011 WP-09 (remove test-env branching from lib) -- next, by hv direction on
  2026-08-04. Taken ahead of WP-07 (purge), which stays queued behind it. This is
  the highest-risk WP in the thread: the suite currently leans on the branches
  being deleted, so budget for test rework rather than a clean sweep.

## TODO

- WP-09 -> WP-07 purge -> WP-10 (docs, changelog, 0.5.0, close issue 0001).
- Gates: full suite green after every WP; rebuild escript and re-run the E-probe
  smoke set after WP-07. Re-baseline the display corpus for any WP whose ACs
  change output and record the diff in impl.md.
- Signal vc via `vc/inbox.cc.md` at each claimed-done.

## WP-09 handoff notes

Measured at this fold, so the next session starts from facts rather than the plan:

- 11 `Mix.env()` sites in `lib/`, across 3 files. AC-09.1 requires zero.
  - `arca_cli.ex`: 7 (lines 148, 190, 377, 402 (commented), 1172, 1254, 1333)
  - `arca_cli/testing/cli_fixtures_test.ex`: 2 (709, 710) -- a test fixture living
    inside `lib/`. Clean it or relocate it, or AC-09.1 cannot pass. vc raised this
    before kickoff and it is recorded on `WP/09/info.md`.
  - `arca_cli/commands/settings_all_command.ex`: 2 (43, 68) -- the `build_test_context`
    fabrication, AC-09.2. WP-06 touched this file but deliberately left these.
- 8 `test_settings` sites across lib and test; 3 `build_test_context` references.
- AC-09.4 (fixture patterns, finding A14) is already satisfied -- fixed in WP-02.
  AC-09.1, AC-09.2, AC-09.3 remain.
- `arca_cli.ex:148` is the branch that never fires (see watch-outs). Deleting it is
  a behaviour-preserving change; anything written assuming it fires is wrong.

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
- Subprocess tests that spawn `mix run` must pass `--no-compile --no-deps-check`
  (the `@mix_run` attribute in the three files that do it). Without them each child
  re-verifies a build the parent just compiled, while holding the global build lock.
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
- (2026-08-04) Verification gap, stated plainly: vc has not answered any of the four
  claimed-done signals (WP-04, 05, 06, 08) and its heartbeat is stale at 08:39Z. My
  close-gates pass, but a gate I wrote checking tests I wrote is not independent
  review. hv is arranging vc review at this fold, which closes the gap.
