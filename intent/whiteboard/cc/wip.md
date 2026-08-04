---
node: cc
name: Control Claude
role: control
session_id: 73036f8b-63e9-4bf1-8d44-40bf1a20a17e
heartbeat_at: 2026-08-04T17:25Z
status: paused
focus: "ST0011 complete, 40/40 PASS; awaiting vc verification and hv release call"
claims: [ST0011]
---

# Control Claude (cc)

## DOING

- Nothing in flight. ST0011 is at 40/40 with all ten WPs Done and issue 0001
  closed. `intent st done ST0011` is deliberately NOT run: the ST-level sign-off
  is vc's, and the release is hv's.

## TODO

Three things are open, and none of them are mine to decide.

- **hv ruling: does the A13 residue join 0.5.0?** Four known commands still report
  failure as ordinary output and exit 0 -- `sys.flush` (A24), `cfg.list`, and the
  failure paths in `base_sub_command.ex:82-95` and
  `coordinator.ex:334-345` (vc's N1). They are named under "Known limitations" in
  the changelog rather than shipped silently. `BaseSubCommand` is the one that
  matters most: it is a library-level path every downstream subcommand inherits.
  The fix shape is ratified and already used for `cfg.get`. A18/A19/A20 are
  reserved for these.
- **hv ruling: the Ctx-renderer error dialect.** String paths use
  `error: <context>: <message>`; the renderer still presents errors its own way.
  Defensible as a presentation-layer boundary, but `grep '^error:'` misses
  Ctx-reported failures.
- **vc's N2, unhomed.** `plain_renderer_test.exs:180` fails on a 40-column
  terminal because tables size against `Owl.IO.columns()` of the test VM.
  WP-07 localised it: `owl_table_helper_test.exs` passes at 40/80/120 columns, so
  the helper is fine when given a width. Fix is to pin `:max_width` in the
  renderer tests.

Also queued, per hv: fixes to `arca_config` itself, from that repo. Two things
found from this side -- a missing key returns `{:error, "Key not found"}`, a
human-readable string rather than a tagged atom, so `Arca.Cli.setting_error/2`
has to match on the text and a wording change there silently breaks the dialect
here; and `delete/1` exists on `Arca.Config.Server` but is not re-exported on the
`Arca.Config` facade the way `get`/`put`/`reload` are.

## Watch-outs

Durable ones only; the WP-specific ones are archived with the work.

- `handle_args/3` is shared by one-shot AND REPL paths. The string-returning
  adapters over `dispatch_args/3` are what keep the REPL working -- do not
  "simplify" them away.
- Test call sites use `Arca.Cli.run/1`, never `main/1`: `main/1` halts and will
  kill the test VM. Downstream wraps `main/1` as its escript entry point, so the
  halt must stay there for them to inherit it from a dep bump alone.
- Renderers must not execute anything. Deferred work resolves in
  `Ctx.add_output/2`, with `Ctx.resolve_output/1` as the safety net.
- Subprocess tests go through `test/support/cli_subprocess.ex` -- do not hand-roll
  another `System.cmd("mix", ...)`. `mix test` does NOT export MIX_ENV, and Mix
  writes its build-lock notice to stdout interleaved with the child's output.
- **An assertion class that passes when the harness is broken is worse than no
  test.** Every `exit == 1` assertion passes when the child never starts. Any
  subprocess suite needs one test proving the child actually ran.
- Do not write tests that depend on whether stdout is a terminal. Run the suite
  BOTH piped and under a pty before claiming.
- Global state shared across test modules -- History, Arca.Config, application env
  -- means a test asserting a count must establish the count it starts from. I
  shipped that flake in WP-07 and caught it at 708/710.
- `config/.env` is gitignored and sets `ARCA_CLI_CONFIG_PATH` during config
  evaluation, overriding the shell. Env-var config isolation silently does not
  apply, and a fresh worktree resolves a different path than the working tree.
- Bumping `VERSION` does not change the built version: `mix.exs` reads it at
  project-load time and Mix does not track it as an input. `touch mix.exs && mix
  compile --force` before building a release.
- zsh does not word-split unquoted vars, and `grep --include=*.ex` needs quoting.
- `vc/inbox.cc.md` shows modified when vc clears my messages. That is vc's change
  to commit, never mine.
- Nothing is "remembered" in prose: every confirmed finding owns a ledger row AND
  an AC. `intent ac status` is the mechanical check.

## Decisions

Kept because they outlive ST0011. The execution record is archived.

- (2026-08-04) Audit verdict: three recurring loss archetypes -- outcomes
  discarded in transit, config read-but-not-honoured, environment-dependent
  behaviour. 0.5.0 fixes the archetypes, not the instances. Evidence:
  `intent/st/ST0011/design.md`.
- (2026-08-04) Several fixes were REMOVALS, not replacements: the forced
  `ansi_enabled: true`, the duplicate default in `config/2`, the DftConfigurator
  fallback, four of five error formatters. **When config is "not being honoured",
  look first for a second writer of the same value.**
- (2026-08-04) The shape that kept recurring, and the one I would carry to any
  other codebase: **a green test suite cannot tell you whether anything reaches
  the code it tests.** A16 (a feature with tests and no call path), A21 (a rule
  whose variable is never set), A22 (an isolation whose variable never wins), the
  whole WP-07 purge, and inverted -- `owl_table_helper.exs`, live code whose tests
  ExUnit never ran. The tests were not weak; they answered "does this work" when
  the live question was "does anything reach it". Those are different questions
  and only one of them a test suite can answer.
- (2026-08-04) A23 is mine, from c9f6460: I made lock messages go away and read
  the silence as success. What it bought was children running against a build
  nobody had compiled. **When a fix makes a symptom disappear, check what else it
  made disappear.**
- (2026-08-04) Zero-caller-in-this-repo is necessary but NOT sufficient for a
  library. hv ruled vc's N4 helpers stay -- correct finding, keep disposition,
  because downstream calls them and this repo cannot see that.
- (2026-08-04) Tests that assert a defect must be changed, not preserved -- and
  every such change is flagged explicitly to vc. 26 in WP-01..08, more since.
- (2026-08-04) vc returned PASS on WP-01..06+08 against the ratified contract with
  its own independent evidence. The verification gap that existed at the previous
  fold is closed. WP-07, 09 and 10 are claimed and not yet verified.
