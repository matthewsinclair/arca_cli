---
node: cc
name: Control Claude
role: control
session_id: 73036f8b-63e9-4bf1-8d44-40bf1a20a17e
heartbeat_at: 2026-08-04T16:20Z
status: paused
focus: "ST0011 44/44 PASS, WP-11 closes the A13 residue; awaiting vc sign-off, then ../arca_config ST0002"
claims: [ST0011]
---

# Control Claude (cc)

## DOING

- Nothing in flight. ST0011 is at 44/44 with eleven WPs Done and issue 0001
  closed. WP-11 closed vc's whole closing batch under hv's "all fixes go into
  this version" ruling. `intent st done ST0011` is deliberately NOT run: the
  ST-level sign-off is vc's, and the release is hv's.

## TODO

- **Await vc's re-verification of WP-11** (claimed at the 17:20 anchor with four
  things to disbelieve). Nothing on my side is open. All three items that used to
  sit here -- the A13 residue ruling, the Ctx-renderer dialect, and vc's homeless
  N2 -- are done and in the contract.
- **Then: `../arca_config` ST0002**, a Fable review of the arca_config base code.
  hv has ruled breaking changes fine there and started a separate CC session in
  that repo; the handover note it was given lives in this session's scratchpad.
  Three defects observed from this side are the seeds: a missing key reported two
  ways (`:not_found` AND the string `"Key not found"`, which forces
  `Arca.Cli.setting_error/2` to text-match); `delete/1` on `Arca.Config.Server`
  but not on the `Arca.Config` facade; and `ARCA_CLI_CONFIG_PATH` resolving
  before `ARCA_CONFIG_PATH`, which is what made A22's isolation inert.
- **If arca_config changes break arca_cli, it is fixed from here.** The tripwire
  to watch: `lib/arca_cli.ex:129` probes
  `function_exported?(Arca.Config, :register_change_callback, 2)` as its "is
  arca_config alive" check. Nothing here CALLS that function -- WP-07 deleted the
  callback subsystem -- so a call-graph search in arca_config will not find this
  consumer. Retiring it there silently turns `config_available?` false and
  degrades every `save_settings` here.

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
- (2026-08-04) vc returned PASS on WP-01..10 against the ratified contract with
  its own independent evidence, holding the ST-level sign-off only for the
  ruled-in closing batch. WP-11 delivered that batch; it is claimed and not yet
  verified.
- (2026-08-04) **A repro names an instance; it does not bound the class.** vc's N2
  named `plain_renderer_test.exs`. Pinning that file left the suite still red at
  40 columns, in `ansi_renderer_test.exs` -- the same defect in the sibling file
  the repro had not reached. Fix the class the repro is an instance of, then run
  the matrix rather than the one case.
- (2026-08-04) **Testing every implementation of an interface is not testing every
  state of it.** A25: the `:ansi` renderer never rendered `ctx.errors` at all, so
  an error-only context printed nothing to an interactive terminal. All three
  renderers had test files. The state that discriminated between them did not
  have a test, so two right answers hid one silent one.
- (2026-08-04) **Making a failure visible is what makes its wording matter.** Six
  coordinator messages read `"Failed to ..."` against the ratified lowercase
  dialect and had never been wrong, because the failure was swallowed before
  anyone saw it. Any future unswallowing needs a dialect pass with it.
- (2026-08-04) WP-08's note claimed "A13 fully closed" and was false when written;
  four more instances existed. Corrected in place with a note rather than quietly
  edited. The evidence for the overclaim was a green suite over the paths we had
  already thought to look at -- which is the WP-09 lesson wearing a different hat.
