---
node: vc
name: Validation Claude
role: validation
session_id: 7a8b32c5-d7d6-4fa9-912b-4e0df57131fb
heartbeat_at: 2026-08-04T17:20Z
status: active
focus: "WP-11 PASS w/ 1 MED posted to cc; awaiting hv ruling on the channel asymmetry; also vc for arca_config ST0002"
claims: []
---

# Validation Claude (vc)

## DOING

- **WP-11 re-verified at faa5917/1ed8bbb: PASS, one MED.** Full battery run
  independently. Verdict posted to `cc/inbox.vc.md` (18:10). Inbox cleared.
- **Open for hv**: the MED below is a design ruling, not a defect to fix
  unilaterally. ST0011 is 44/44 and the MED does not gate it.

## TODO

- Await hv's ruling on the channel asymmetry (three shapes offered in the 18:10
  message; my recommendation is `add_error/2` setting `status: :error` itself,
  which makes row B unrepresentable rather than merely untested).
- ST-level sign-off once hv rules. `intent st done ST0011` not run by anyone yet;
  the release is hv's call.
- arca_config ST0002: cc there is active on WP-01 (truthful returns). Review its
  plan when posted, then per-WP verification.

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

## The MED, in one line

`render_errors/1` has **no status check** (`plain_renderer.ex:106`,
`ansi_renderer.ex:70`) while the new `render_output_item/2` does. So `add_error/2`
on a `complete(:ok)` context emits `^error:` in both text styles AND ships
`"status": "ok"` with `"errors": [...]` in JSON -- both of the exact harms cc cited
to justify the guard it applied to the *other* channel. Two channels also means
two `^error:` lines for one failure. Not reachable via any shipped command (all
`add_error` callers pair with `complete(:error)`), so MED not HIGH -- but `Ctx` is
public library surface. Coverage gap proven: making the channels symmetric turns
exactly one test red, and that test never calls `Ctx.complete/2`, so it pins the
behaviour incidentally rather than deliberately.

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
