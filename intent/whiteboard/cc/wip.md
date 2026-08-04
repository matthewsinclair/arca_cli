---
node: cc
name: Control Claude
role: control
session_id: 73036f8b-63e9-4bf1-8d44-40bf1a20a17e
heartbeat_at: 2026-08-04T17:07Z
status: active
focus: "WP-11 PASSed by vc; one MED open on who decides a Ctx failed; awaiting hv ruling"
claims: [ST0011]
---

# Control Claude (cc)

## DOING

- Nothing in flight. ST0011 is at 50/50 with thirteen WPs Done, issue 0001
  closed, 772 green, no OPEN ledger rows.
- **`intent st done ST0011` and the 0.5.0 tag are BLOCKED on arca_config**
  (hv, 2026-08-04). Not a formality and not just sequencing: `mix.lock` pins
  arca_config to commit `8b30615` on `branch: main`, so everything verified so
  far -- 764 green, the escript probe, every AC -- was verified against the
  arca_config that existed BEFORE its ST0002 work. **That evidence does not
  transfer.** When arca_config lands: `mix deps.update arca_config`, then re-run
  the whole battery (seeds, widths, pty/piped, escript probe, `intent ac status`)
  before anything is signed off or tagged. Re-verification is the gate, not the
  dep bump.
- Open question for hv before tagging: 0.5.0 would freeze a `branch: main` git
  dep, so a later build of the tag resolves a different arca_config than the one
  released. Fine if the two always ship together and nothing external consumes
  the tag; not fine otherwise. Pre-existing, not introduced by ST0011.

## TODO

- **Await vc's verification of WP-13 (A29).** vc filed it as dormant-until-the-
  bump; it is live on the current pin. The pinned arca_config only falls back
  silently for a MISSING config -- a config that EXISTS and does not parse reaches
  the identical path today, which is the trigger the fix is verified against.
  Neither the bump nor a local arca_config was needed to reproduce it, so hv's
  single-bump ruling is not engaged: nothing in WP-13 touches a dependency.
  Scope taken past the filed finding: the startup warning in `run/1` discarded
  the reason too, which is vc's unfiled `about`/`cli.status` observation with its
  actual cause.
- **vc's harness has a blind spot and should gain a BADCFG row.** It probes only
  the missing-config trigger, so on this pin it cannot see A29 or its fix -- the
  behaviour probe is byte-identical before and after. A config-present-but-
  unparseable row fires on BOTH pins. Reported; the harness is vc-owned.
- **WP-12 (A28) PASSED by vc**, with all four of my challenges answered. Landed: one
  authority, `Ctx.outcome/1` + `Ctx.failed?/1`, with the exit status, both text
  renderers' dialect line and the JSON status field deriving from it. The
  private `ctx_outcome/1` is gone from `arca_cli.ex`. Within each renderer both
  failure channels now share one `render_failure/2`: the dialect line is gated,
  the ✗ marker never is.
  The two rows that were wrong: `add_error |> complete(:ok)` exited 0 while
  printing `error:` (A13 inverted), and `add_error` with no `complete/2` exited
  1 while its JSON carried no status key at all -- the second was outside the
  matrix vc filed. Neither of vc's two proposed shapes was taken; reasons are on
  AC-12.1 and in impl.md, and vc should attack that.
- **If arca_config changes break arca_cli, it is fixed from here** -- that is the
  whole reason this node stayed open. `../arca_config` ST0002 belongs to a
  SEPARATE cc session with its own node and session_id; do not conflate the two.
  The tripwire to watch: `lib/arca_cli.ex:129` probes
  `function_exported?(Arca.Config, :register_change_callback, 2)` as its "is
  arca_config alive" check. Nothing here CALLS that function -- WP-07 deleted the
  callback subsystem -- so a call-graph search over there will not find this
  consumer. Retiring it silently turns `config_available?` false and degrades
  every `save_settings` here.

## Watch-outs

Durable only. WP-specific ones are archived with the work.

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
- **The environment of a test run is not an input to it.** Do not depend on
  whether stdout is a terminal, and pin `:max_width` on any table test that reads
  positions out of a rendered line. Run the suite piped AND under a pty, and
  across widths, before claiming.
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
  This has now cost two probe runs that returned plausible numbers for the wrong
  reason.
- `vc/inbox.cc.md` shows modified when vc clears my messages. That is vc's change
  to commit, never mine.
- Nothing is "remembered" in prose: every confirmed finding owns a ledger row AND
  an AC. `intent ac status` is the mechanical check.

## Decisions

Kept because they outlive ST0011. The execution record is archived under
`.history/20260804/`.

### The thread's verdict

- (2026-08-04) Three recurring loss archetypes -- outcomes discarded in transit,
  config read-but-not-honoured, environment-dependent behaviour. 0.5.0 fixes the
  archetypes, not the instances. Evidence: `intent/st/ST0011/design.md`.
- (2026-08-04) Several fixes were REMOVALS, not replacements: the forced
  `ansi_enabled: true`, the duplicate default in `config/2`, the DftConfigurator
  fallback, four of five error formatters. **When config is "not being honoured",
  look first for a second writer of the same value.**

### The one shape, and its instances

- (2026-08-04) The finding I would carry to any other codebase: **a green test
  suite cannot tell you whether anything reaches the code it tests.** It answers
  "does this work", never "does anything get here", and those are different
  questions. Every instance in this thread is a variation on it:
  - A16 -- a feature with unit tests and no call path.
  - A21 -- a rule whose variable is never set.
  - A22 -- an isolation whose variable never wins.
  - A25 -- **testing every implementation of an interface is not testing every
    state of it.** All three renderers had test files; the state that
    discriminated between them did not, so two right answers hid one that
    rendered errors not at all.
  - A26 -- **a construct gate cannot prove the new branch is reachable.** The fix
    returned the right tuple from a branch nothing could execute. Absence-of-the-
    old is not presence-of-the-new.
  - A28 -- **asserting presence cannot catch an over-report.** The cross-product
    covering the dialect line pinned `complete(:error)` on every row, so the
    axis that discriminated was held constant, and it asked only that the line
    appear. The broken row appeared and passed. Where a claim is really an iff,
    assert the iff.
  - Inverted: `owl_table_helper.exs`, live production code whose tests ExUnit had
    never once run.

### Corollaries for building

- (2026-08-04) **When a fix makes a symptom disappear, check what else it made
  disappear.** A23 is mine: I silenced build-lock noise and bought children
  running against a build nobody had compiled.
- (2026-08-04) **A repro names an instance; it does not bound the class.** vc's N2
  named one test file; pinning it left the suite still red in the sibling file.
  Fix the class, then run the matrix rather than the one case.
- (2026-08-04) **Making a failure visible is what makes its wording matter.** Twice:
  the coordinator's six messages and History's four, both capitalised against the
  ratified dialect, both harmless only because the failure was swallowed before
  anyone saw it. Ship a dialect pass with any unswallowing.
- (2026-08-04) Zero-caller-in-this-repo is necessary but NOT sufficient for a
  library. hv ruled vc's N4 helpers stay -- correct finding, keep disposition,
  because downstream calls them and this repo cannot see that.
- (2026-08-04) **A question answered in more than one place is eventually
  answered differently.** Four sites decided whether a Ctx had failed; two came
  to disagree with the exit code. The fix is not to make them consistent -- that
  is maintenance forever -- but to leave one of them. Highlander applies to
  predicates, not just modules. The tell that two branches should already have
  been one function: their outputs were byte-identical, written twice.

### Corollaries for claiming

- (2026-08-04) **Completeness claims earn a probe, not a sentence.** I corrected an
  overclaim about A13 and wrote a new one with identical structure in the same
  batch. The counter has to be structural: a cross-product test over whatever the
  claim quantifies over, so a new member of either dimension fails until covered.
  Both times this bit, the untested COMBINATION was the broken one.
- (2026-08-04) **"There is no seam" is a claim to check, not to reason to.** I wrote
  "no seam without mocking" into an AC. The seam was `Process.unregister(History)`
  in a test file I wrote myself in WP-05.
- (2026-08-04) **When every row of a result table agrees, check the harness can
  produce disagreement.** Three instances now: A23, A26, and a probe loop where
  zsh's lack of word-splitting made every row read `exit=1` for the wrong reason.
- (2026-08-04) **Predict the failing set before running the mutation, and treat a
  shortfall as a finding.** A29's tests were predicted to turn 4 red and turned
  2. The two that held passed *against the broken code*, because the leaked
  `%MatchError{}` contains the reason string, so assertions scanning the whole
  output found it while the user was still being told "Unknown error loading
  settings" -- a check satisfied by the very leak it forbids. Assert on the
  user-facing line, not on the combined output. Had I only counted "some tests
  went red", both weak tests would have shipped looking rigorous.
- (2026-08-04) **"Dormant until X" is a claim about triggers, and one trigger is
  not the class.** A29 was filed as going live at the dep bump, true of the
  missing-config trigger and false of the corrupt-config one, which fires today.
  Before deferring a fix to an event, ask what else reaches the same path.
- (2026-08-04) Tests that assert a defect must be changed, not preserved -- and
  every such change is flagged explicitly to vc. 26 in WP-01..08, more since.

### Verification state

- (2026-08-04) vc PASSed WP-01..10 on its own independent evidence and held the
  ST-level sign-off for the ruled-in closing batch. WP-11 delivered it, came back
  NOT PASS on one HIGH, was fixed and re-claimed. Not yet re-verified.
