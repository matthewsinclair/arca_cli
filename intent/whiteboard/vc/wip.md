---
node: vc
name: Validation Claude
role: validation
session_id: 7a8b32c5-d7d6-4fa9-912b-4e0df57131fb
heartbeat_at: 2026-08-04T19:30Z
status: active
focus: "WP-12 PASS; NEW finding A29 -- cfg.list destroys the load diagnosis, goes live on the arca_config dep bump"
claims: []
---

# Validation Claude (vc)

## DOING

- **WP-12 verified at c85fc2f: PASS.** 764 green x seeds 1/3/11/77/555/4242,
  47/47, escript 5x(0/0) + 6x(1/1). cc's A28 diagnosis was better than my MED --
  the duplication was the predicate, not the channels. Matrix re-driven myself:
  every row's `^error:` matches `Ctx.outcome/1`, JSON carries a status on all
  eight rows, and the `✗` is present in EVERY row (gating never swallows).
- **NEW, A29 -- MED-HIGH, filed to cc and hv.** `cfg.list` destroys the load
  diagnosis. With a missing config: `cfg_commands.ex:74` strict-matches
  `{:ok, settings} = Arca.Cli.load_settings()`, the MatchError hits a catch-all
  `rescue e ->` at `:83-87`, and the user gets "Unknown error loading settings"
  plus a raw `%MatchError{}` logged to their terminal. Sibling `settings.all`
  carries `enoent` through correctly. **ST0011 verified A19 as satisfied -- the
  path does return a tagged tuple. Nobody asked what the tuple SAYS.** My miss as
  much as cc's; I signed off that WP.
- **A29 is dormant only because of the stale pin.** The pinned arca_config
  silently falls back to a different config and exits 0. arca_config's WP-04 fixes
  that, which makes A29 live. The suite stays green straight through the bump.
- **WP-11 re-verified at faa5917/1ed8bbb: PASS, one MED.** Full battery run
  independently. Verdict posted to `cc/inbox.vc.md` (18:10). Inbox cleared.

## TODO

- **A29 needs a home.** Recommend its own WP-13 rather than smuggling it into the
  dep bump: `with`-railway the load in `cfg_commands.ex` so the reason survives,
  demote the catch-all rescue to a genuine unexpected-exception guard, and add an
  AT that drives a missing config location and asserts the reason reaches the user.
  hv's call whether it lands before or after the arca_config bump.
- **Insist the re-verification gate includes missing-config escript probes.** cc's
  gate note (988b5fb) is right that the 764-green evidence does not transfer across
  the dep bump -- but seeds alone would not have caught A29 either. Behaviour, not
  counts.
- ST-level sign-off and the 0.5.0 tag are hv's. cc's flag about tagging freezing a
  `branch: main` git dep is a real release hazard and still open.
- arca_config ST0002: WP-01/03/04 PASSed. WP-02 unblocked (Ask 1 answered), WP-05
  waits on hv's R3.

## WP-11 re-verify -- what I actually ran (2026-08-04 18:00-18:10)

- **A26/A24 HIGH: CLOSED.** Driven, not read. History up -> success string;
  `Process.unregister(Arca.Cli.History)` -> `{:error, :history_operation_failed,
  "failed to clear command history: history service is not available"}`,
  `is_binary/1` false. `flush_command_history/0` now `case`s on the return.
- **AT-11.7 discriminates -- cc's falsification claim verified by re-running it.**
  Guard made unmatchable -> exactly the two error-output-item rows red, 40/42.
- **Finding 3 done**: hv ack transcribed on AC-07.2, the "hv can rule the
  remainder" sentence withdrawn with my retraction beside it.
- **Changelog**: both false completeness sentences corrected; "None outstanding"
  replaced by a bounded statement naming the no-message case.
- **Regression**: only 4 lib files moved since 5bdebe4 (sys_flush, history, both
  renderers). A18/A19/A20 untouched; A25's `join_sections`/`render_errors` intact.
- **Battery**: 736 green x seeds 3/11/77/555; `--warnings-as-errors` and
  `--check-formatted` clean; escript rebuilt from forced prod compile, reports
  0.5.0; `intent ac status ST0011` 44/44 PASS; probes clean, `cli.error ctx` now
  has both the cross mark and the dialect line (both halves of hv's ruling).

## The WP-11 MED -- CLOSED by WP-12

Was: `render_errors/1` had no status check while `render_output_item/2` did, so
`add_error |> complete(:ok)` emitted `^error:` while exiting 0. cc's WP-12 fixed
the cause rather than the symptom -- `Ctx.outcome/1` + `failed?/1` are now the
single authority and all four sites derive from it. Re-driven and confirmed.

## Watch-outs

- **zsh does not word-split unquoted vars.** A probe loop of `"$E" $c` runs the
  whole string as ONE argument, so every row silently measures unknown-command
  output -- uniform, correct-looking, wrong. Use a function taking `"$@"`. This
  has now bitten cc twice and me once. When two probes disagree, resolve at byte
  level (`od -c`) before reporting either.
- **A construct gate cannot prove reachability.** Grepping the old string away
  says nothing about whether the new branch can execute. When a builder says "no
  seam exists", look for a seam the project already built -- WP-05's
  `Process.unregister(Arca.Cli.History)` drove A24 in two lines.
- **Completeness claims are this codebase's recurring failure.** A16, A21, A22,
  A26 are all "green tests over code nothing reaches". Probe every "fully closed"
  / "none outstanding" sentence rather than reading it.
- For a LIBRARY, zero-callers-in-this-repo never implies removable -- the repo
  cannot observe its consumers. In-repo silence over public surface means
  UNTESTED CONTRACT SURFACE; the remedy is tests, not deletion. (hv corrected me
  on this twice: the N4 helpers, then arca_config's deps.)
- Never attach an hv ruling to a conclusion hv did not reach. Relay rulings
  verbatim under a `RULINGS` first line so they are greppable and survive a fold.
- Two different cc SESSIONS exist (arca_cli, arca_config) -- distinct nodes and
  session_ids. Do not conflate. No `hv` node on either board by hv's ruling;
  escalations go in-session.
- Inbox anchors are NOT monotonic -- thread by file position, not timestamp.
- Release trap: bumping VERSION does not rebuild. `touch mix.exs && mix compile
  --force` before `mix escript.build`, or the release binary reports the old
  version. Check the final escript reports 0.5.0 at sign-off.
- Do not run `mix` while cc is mid-flight -- the build lock is shared and Mix
  writes its lock notice to stdout, interleaved with output under assertion.

## Decisions

- (2026-08-04) WP-12: **PASS at c85fc2f**, and cc's diagnosis beat my MED. I framed
  it as "which status gates the line"; the real defect was four sites independently
  answering "did this ctx fail". Lesson for me: when a finding is an asymmetry, ask
  what the two sides are BOTH deriving from before proposing to align them.
- (2026-08-04) A29 filed: A19 was verified as returning a tagged tuple and nobody
  asked what the tuple says. **"Returns the right SHAPE" is not "reports the right
  THING".** Add it to the reachability lens -- drive the branch, then read what the
  user actually sees.
- (2026-08-04) A green downstream suite is not downstream evidence: arca_cli held
  764 green across arca_config's WP-01/03/04 while its missing-config behaviour
  changed materially. Only escript probes found it.
- (2026-08-04) WP-11 re-claim: **PASS at 1ed8bbb**, one MED (channel asymmetry,
  above) referred to hv rather than treated as a blocker. The HIGH is closed and
  I drove it myself. cc's discrimination claim for AT-11.7 held up under my own
  falsification -- the first time in this thread a builder's "proven to
  discriminate" survived being re-run.
- (2026-08-04) Method note that earned its keep: the finding came from probing a
  matrix cc had not -- it tested channel x style with status pinned to `:error`;
  the defect lived on the status axis. When a builder presents a cross-product,
  check which axis it *fixed*.
- (2026-08-04) WP-11 first claim: NOT PASS at 5bdebe4. HIGH = A24's fix inert
  (branch unreachable; WP-05's `call/3` removed the exception the rescue needed).
  MED-HIGH = `^error:` covered `Ctx.add_error/2` but not
  `Ctx.add_output({:error,_})`. MINOR = AC-07.2 ack untranscribed. Everything
  else clean. Re-claimed by cc at faa5917; re-verification pending.
- (2026-08-04) Method, unchanged and paying off: fire on claim, read the as-built
  not the narrative, every finding carries file:line, self-refute HIGH findings
  first, state coverage gaps explicitly, and prefer driving a branch over
  reasoning about it.
- Earlier settled decisions, the full verification record, and the adopted-findings
  table are in `.history/20260804/wip.md`.
