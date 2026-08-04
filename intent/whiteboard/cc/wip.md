---
node: cc
name: Control Claude
role: control
session_id: 73036f8b-63e9-4bf1-8d44-40bf1a20a17e
heartbeat_at: 2026-08-04T20:10Z
status: paused
focus: "ST0011 57/57, fifteen WPs, 782 green on arca_config 0.3.0; handed to vc to verify the release"
claims: [ST0011]
---

# Control Claude (cc)

## DOING

- Nothing in flight. ST0011 is at 57/57 with fifteen WPs Done, issue 0001 closed,
  782 green **against arca_config 0.3.0**, no OPEN ledger rows. Working tree clean.
- `intent st done ST0011` and the `v0.5.0` tag are NOT run. Sign-off is vc's
  verification plus hv's release call.

## TODO

- **Handed to vc: verify the release.** WP-13 (A29), WP-14 (A30, A31) and WP-15
  (A32, A33, A34) are all claimed and unverified. The bump has HAPPENED -- the
  earlier "blocked on arca_config" note is spent.
- **vc's harness needs a BADCFG row**, and its header currently asserts something
  false: it stamps "A29 rows CANNOT fire" on pinned runs. True of the
  missing-config trigger, false of the corrupt-config one. vc owns that file.

## Watch-outs

Durable only. WP-specific ones are archived with the work.

- **The escript is a separate artifact and goes stale silently.** `touch mix.exs
  && MIX_ENV=prod mix compile --force && mix escript.build` before believing any
  probe and before any release. Bumping `VERSION` alone does not rebuild it. This
  bit twice, the second time from *inside* the suite:
  `cli_debug_persistence_test.exs` drives the built binary, so it kept failing
  after the source was already correct.
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
  -- means a test asserting a count must establish the count it starts from.
- `config/.env` is gitignored, holds live secrets, and `config/dotenv.exs` calls
  `System.put_env/2` under :dev and :test -- so it OVERWRITES
  `ARCA_CLI_CONFIG_PATH` from the parent environment and a child cannot be
  steered by exporting it. Set it inside evaluated code, after config evaluation.
- The arca_config coupling is asserted in `test/arca_cli/config_contract_test.exs`
  -- **add new coupling there, not to this list.** It pins the facade calls, the
  two unavoidable `Server` calls, and the `register_change_callback/2` liveness
  probe that nothing calls and no call-graph search can find.
- zsh does not word-split unquoted vars, and `grep --include=*.ex` needs quoting.
- `vc/inbox.cc.md` shows modified when vc clears my messages, and vc's `probes/`
  shows modified when I run its harness. Both are vc's to commit, never mine.
- Nothing is "remembered" in prose: every confirmed finding owns a ledger row AND
  an AC. `intent ac status` is the mechanical check.

## Decisions

Kept because they outlive ST0011. The execution record is archived under
`.history/20260804/`.

### The thread's verdict

- (2026-08-04) Three recurring loss archetypes -- outcomes discarded in transit,
  config read-but-not-honoured, environment-dependent behaviour. 0.5.0 fixes the
  archetypes, not the instances. Evidence: `intent/st/ST0011/design.md`.
- (2026-08-04) Several fixes were REMOVALS, not replacements. **When config is
  "not being honoured", look first for a second writer of the same value.**
- (2026-08-04) **Four of the 34 findings landed after the thread looked
  finished**, three of them found by vc verifying a PASS. A clean verification is
  where to look next, not where to stop.

### The one shape, and its instances

- (2026-08-04) The finding I would carry to any other codebase: **a green test
  suite cannot tell you whether anything reaches the code it tests.** It answers
  "does this work", never "does anything get here". Instances: A16 (feature with
  no call path), A21 (rule whose variable is never set), A22 (isolation that
  never wins), A25 (testing every implementation of an interface is not testing
  every state of it), A26 (a construct gate cannot prove the new branch is
  reachable), A28 (asserting presence cannot catch an over-report). Inverted:
  `owl_table_helper.exs`, live code whose tests ExUnit had never once run.

### Corollaries for building

- (2026-08-04) **A question answered in more than one place is eventually
  answered differently.** Four sites decided whether a Ctx had failed and two
  came to disagree with the exit code. The fix is not to make them consistent --
  that is maintenance forever -- but to leave one of them. Highlander applies to
  predicates. The tell that two branches should already have been one function:
  their outputs were byte-identical, written twice.
- (2026-08-04) **Making a failure visible is what makes its wording matter.**
  Four times now: the coordinator's six messages, History's four, the config load
  reason, and arca_config's new error tuples. Ship a dialect pass with any
  unswallowing.
- (2026-08-04) **When a fix makes a symptom disappear, check what else it made
  disappear.** A23 is mine: I silenced build-lock noise and bought children
  running against a build nobody had compiled.
- (2026-08-04) **A repro names an instance; it does not bound the class.** And
  "dormant until X" is a claim about triggers: A29 was filed as going live at the
  dep bump, true of the missing-config trigger and false of the corrupt-config
  one, which fired that day.
- (2026-08-04) Zero-caller-in-this-repo is necessary but NOT sufficient for a
  library. Downstream calls what this repo cannot see.

### Corollaries for claiming

- (2026-08-04) **Predict the failing set before running a mutation, and treat a
  shortfall as a finding.** A29's tests were predicted to turn 4 red and turned
  2. The two that held passed *against the broken code*, satisfied by the very
  leak they forbade. Counting "some tests went red" would have shipped two weak
  tests looking rigorous.
- (2026-08-04) **An assertion that the right text APPEARS is satisfied by wrong
  output containing it.** Three times in one day: the `%MatchError{}` leak
  containing its own reason string, AT-11.7 asserting presence where it needed a
  biconditional, and A34's doubled message. Where a claim is really an iff,
  assert the iff; where it is "exactly once", count.
- (2026-08-04) **Completeness claims earn a probe, not a sentence.** The counter
  is structural: a cross-product over whatever the claim quantifies over, so a
  new member of either dimension fails until covered. Every time this bit, the
  untested COMBINATION was the broken one.
- (2026-08-04) **"There is no seam" is a claim to check, not to reason to.** I
  wrote "no seam without mocking" into an AC. The seam was in a file I had
  written myself.
- (2026-08-04) **When every row of a result table agrees, check the harness can
  produce disagreement.** A23, A26, and a probe loop where zsh's lack of
  word-splitting made every row read `exit=1` for the wrong reason.
- (2026-08-04) **Check `mix.lock` is committed before believing any claim that a
  git dep makes a build irreproducible.** I raised that one and was wrong.

### Verification state

- (2026-08-04) vc PASSed WP-01..12 on its own independent evidence. WP-13, WP-14
  and WP-15 are claimed and awaiting verification. ST-level sign-off is hv's.
