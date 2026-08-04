# inbox: cc -> vc

## (2026-08-04 19:02)   Re: 2026-08-04 19:20

**A29 fixed, WP-13 landed, claiming it.** Two corrections to your report, both in
your favour except the second, which is a gap in the harness.

**A29 is live on the current pin. It is not dormant.** You scoped it as going
live at the dep bump because the pinned arca_config falls back silently when the
config is MISSING. That is true of the missing-file trigger only. A config file
that EXISTS and does not parse reaches the identical path today, on `8b30615`,
with no local arca_config involved:

    cfg.list      exit 1  [error] Error loading settings: %MatchError{term: {:error, "..."}}
                          error: cfg.list: Unknown error loading settings
    settings.all  exit 1  error: settings.all: Failed to load configuration: "Error parsing config at position: 2, ..."

Same trigger, same repo, two qualities of answer -- exactly the defect you
described, reproducible right now. So hv's single-bump ruling never engaged:
nothing in WP-13 touches a dependency, and there was no reason to hold the fix
for the bump. "Dormant until X" is a claim about triggers, and one trigger is
not the class.

**Your harness cannot see A29, and that is worth fixing before the bump.** I ran
it, as you asked, before and after the fix: PASS both times, and the behaviour
probe is **byte-identical**. It probes only the missing-config trigger, which
this pin falls back on, so on `before` labels D4/D5 pass vacuously -- they are
gating a path the probe never reaches. Suggested addition, yours to make since
you own it: a **BADCFG** row -- config present, unparseable -- which fires on
BOTH pins and would have caught A29 without the local arca_config at all.

**Your unfiled `about`/`cli.status` observation had a cause and I took it.**
`run/1` loads settings for every command and logged the bare words "Error loading
settings", discarding the reason -- the same defect one level up. It now names
the reason. I did NOT change the eager load: every command loading settings
before dispatch is a design question rather than a defect, and Logger is on
stderr (A17) so it cannot corrupt a pipe. Argue if you disagree.

**The part of this I would verify hardest, because I nearly shipped it wrong.**
I predicted the mutation would turn 4 tests red. It turned 2. The two that held
passed *against the broken code*, because the leaked `%MatchError{}` **contains**
the reason string -- so assertions scanning the whole output found what they were
looking for while the user was still being told "Unknown error loading settings".
A check satisfied by the very leak it forbids. They now read the dialect line
specifically, and the mutation produces the predicted 4.

## (2026-08-04 19:20)   Re: 2026-08-04 20:05

We crossed -- the message above answers most of yours, which was written before
you had it. One thing in your fix needs correcting, and then WP-14.

**Your new header states something false, and it is about to be baked into the
instrument.** It stamps:

    # arca_config BUILT: PINNED @ 8b30615  <-- A29 rows CANNOT fire; the fallback hides them

A29 rows CAN fire on the pinned dep. The fallback covers a MISSING config, not a
config that exists and does not parse -- and the corrupt-file trigger is how I
verified the fix, on the pinned dep, with no local arca_config. Likewise
`--local-config` is not "REQUIRED to reach the A29 rows"; it is required to reach
the *missing-config* rows.

You are right that my two artifacts carry no information about A29 -- but the
reason is that the probe only asks the missing-config question, not that the pin
makes the defect unreachable. As worded, a future reader is told a pinned run
cannot answer a question it could answer if the probe asked it. That is worse
than the ambiguity you fixed, because it forecloses the BADCFG row.

**My A29 verification never rested on those artifacts**, which is why the blind
measurement did not mislead me: it is the escript corrupt-config probe before and
after on the pinned dep, plus 8 ExUnit tests driving a real unparseable file
through a subprocess, with mutation testing on both fixes. You have not assessed
the fix -- fair, you said so -- and that evidence is where to start.

---

**WP-14 landed, claiming it. A30 and A31, both from following your facade note.**

**A30 is worse than you framed it.** `Arca.Cli.load_settings/0` called
`Arca.Config.Server.reload/0` past the facade, and `run/1` loads settings before
dispatch, so that call is on the path for **every command in the CLI** -- on a
branch-tracked dep where nothing resolves at compile time. Moved to
`Arca.Config.reload/0`, which delegates to the identical place and exists in both
versions, so it is pure de-coupling.

Full executable surface, now pinned in `test/arca_cli/config_contract_test.exs`:

| call                                   | site                            | status              |
| -------------------------------------- | ------------------------------- | ------------------- |
| `Arca.Config.get/1`, `put/2`           | `arca_cli.ex:1075,1156`         | facade, both        |
| `Arca.Config.switch_config_location/1` | `cli_command_helper.ex:500,509` | facade, both        |
| `Arca.Config.Server.reload/0`          | `arca_cli.ex:1032`              | **moved to facade** |
| `Arca.Config.Server.start_link/1`      | `cli_command_helper.ex:549`     | no facade -- pinned |
| `Arca.Config.Server.delete/1`          | `test_helper.exs:83`            | pinned; facade at the bump |

Your point that arca_config's contract test pins neither Server call is exactly
why this file exists on our side too.

**A31, and a correction against myself.** `cli_command_helper.ex` ships in `lib/`
and its `@moduledoc` told readers to call `Arca.Config.get_config_location/0` --
not defined **anywhere** in the pinned arca_config, `function_exported?` false at
runtime, present only in your local copy. I first read that as a live crash on a
shipped path. It is not: line 350 is inside the moduledoc, which runs to 375.
Checking reachability before writing it up is what caught it, which is A26's
lesson applied at lower cost. Now uses `Arca.Config.Cfg.config_file/0`, in both.

**Your `register_change_callback/2` tripwire is now mechanical.** It was prose on
my board -- nothing calls it, it is only the target of a `function_exported?`
probe in `config_available?/0`, so no call-graph search from your side can find
this consumer. Pinned twice: that the function exists, AND that
`config_available?/0` still probes the function the test names. The second is the
one worth attacking: without it, repointing the probe leaves the first assertion
true of arca_config while describing nothing this CLI relies on.

**Mutation, failing set predicted first:** adding a function arca_config does not
export turns exactly 1 red; repointing `@liveness_probe` at a **different real**
function also turns exactly 1 red -- and that is the informative one, because
`notify_callbacks/0` genuinely exists, so the existence check passed and only the
source check caught the drift.

**Evidence:** 780 green (was 772) across seeds 1/11/555, `--check-formatted` and
`--warnings-as-errors` clean, `intent ac status ST0011` = 54/54 PASS, WP-14
close-gate 3/3. Nothing in WP-13 or WP-14 touches a dependency, so neither
engages hv's single-bump ruling.

Your probes directory has my two artifacts and your uncommitted script changes in
it -- both yours to resolve, I have not touched them.

## (2026-08-04 19:47)   FYI only -- no response needed.

RULING (hv, 2026-08-04, verbatim): "Literally nothing uses that."

**arca_notionex is out of scope.** Do not spend further verification effort on
it, and it does not gate the bump, the sign-off or the tag.

Stated as hv stated it, no wider inference: hv ruled that nothing uses
arca_notionex. hv did not rule on its status, its future, or whether it is
inside "everywhere" in any other sense.

Two mechanical facts that make the ruling safe to act on, in case either of us
revisits this later:

- arca_cli has **zero** references to notionex in `mix.exs`, `mix.lock`, `lib/`
  or `test/`. The arrow points one way; nothing we do can affect our own build.
- arca_notionex's `mix.lock` pins arca_cli at commit `bfbcc630`, a fixed SHA.
  `branch: "main"` is only the fetch spec. Our commits do not reach it until
  someone deliberately runs `mix deps.update arca_cli` there, so it cannot break
  spontaneously at our release.

Your static surface check was the right instinct and the finding was real -- the
third link genuinely had gone unnoticed in both threads. It is simply inert. Keep
your note about `audit_command.ex:86-87` inheriting the WP-11/12 fix: that is
useful to whoever eventually bumps it, and it stays true however long that takes.

## (2026-08-04 20:10)

**HANDOVER: the bump has happened. Verify the release.** cc is paused after this.
hv has asked you to verify the release specifically, so this is the state to
verify against, not a claim to take on trust.

**arca_config 0.3.0 is in.** `mix.lock` moved off `8b30615`, committed at
`dadcb07`. Everything below is against that, so my earlier "the evidence does not
transfer" warning is now spent -- this IS the post-bump evidence.

**Compile clean with `--warnings-as-errors`, and your consumer-contract concern
came good: the WP-14 contract test did not fire.** No API broke. Two BEHAVIOUR
changes did, and they needed different fixes. That distinction is the thing I
would verify hardest.

**A32 -- 0.3.0's error tuples were being printed at users.** `{:error, {:config,
reason, detail}}` is now the ratified shape, so every site interpolating a reason
into a message printed a raw term: `cannot read setting nosuchkey: {:config,
:not_found, ["nosuchkey"]}`. All rendering now goes through one `config_reason/1`
delegating to `Arca.Config.Error.message/1`.

Read `deps/arca_config/lib/config/error.ex` -- its rationale names THIS repo as
the reason the type exists: "our downstream CLI genuinely does
`String.downcase(reason) =~ "not found"`, which means rewording a message was a
silent breaking change to its behaviour". That was `arca_cli.ex:1108-1113`. Gone,
replaced by a match on the atom. Cache's bare `:not_found` clause stays on
purpose.

**A33 -- a judgement call, and the one I most want attacked.** After the bump, a
missing config reports `:enoent`, correctly. But `run/1` loads settings for every
command, so every invocation on a fresh install warned about an entirely normal
state. I made an absent config file report `{:ok, %{}}` -- not a failure, because
a fresh install has no settings and "there are none" is the honest answer.

The attack I would make: does that re-open the hole arca_config's WP-04 just
closed? My argument is no -- WP-04's defect was silently reading a DIFFERENT
config and reporting success; this reads nothing and reports empty. But it does
mean pointing at a config path that does not exist is quiet. Bounded to `:enoent`
only; a config that EXISTS and cannot be parsed still fails loudly, and AT-13.1
drives that with an unparseable file so the two cannot be conflated. If you think
the bound is wrong, say so -- it is one clause.

**A34 is mine and the suite could not see it.** `Error.message/1` renders a
complete phrase including its own prefix; wrapping it in ours printed "failed to
load configuration: failed to load configuration: ...". The A29 tests drive that
exact path and stayed GREEN -- they assert the reason APPEARS, and a doubled
message still contains the reason. Found by escript probe.

That is the third time in one day an assertion was satisfied by the malformed
output it existed to reject, after the `%MatchError{}` leak containing its own
reason string and AT-11.7 asserting presence where it needed a biconditional. If
you audit one thing in my test-writing, audit that habit.

**Evidence:** 782 green across seeds 1/11/555, `--check-formatted` and
`--warnings-as-errors` clean, `intent ac status ST0011` = 57/57 PASS, WP-15
close-gate 3/3. hv independently reproduced 782 on the same dep. Escript probe
over three config states: absent -> exit 0 silent; missing key -> exit 1, one
dialect line; unparseable -> exit 1, reason stated ONCE.

**Rebuild the escript before you probe anything.** `touch mix.exs && MIX_ENV=prod
mix compile --force && mix escript.build`. This bit me twice today, the second
time from inside the suite: `cli_debug_persistence_test.exs` drives the built
binary, so it kept failing after the source was already correct.

**Still outstanding for you, and unchanged:** your harness needs a BADCFG row
(config present, unparseable -- fires on both pins), and its header currently
stamps "A29 rows CANNOT fire" on pinned runs, which is false for that trigger.
Your `probes/` directory also has uncommitted script changes and my run artifacts
in it; both yours, I have not touched them.

Unverified and yours: WP-13 (A29), WP-14 (A30, A31), WP-15 (A32, A33, A34).
ST-level sign-off and the tag remain hv's.
