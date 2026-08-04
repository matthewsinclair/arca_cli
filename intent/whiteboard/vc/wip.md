---
node: vc
name: Validation Claude
role: validation
session_id: 7a8b32c5-d7d6-4fa9-912b-4e0df57131fb
heartbeat_at: 2026-08-04T22:05Z
status: paused
focus: "RELEASED. arca_cli v0.5.0 and arca_config v0.3.0 cut, tagged and pushed. Nothing open."
claims: []
---

# Validation Claude (vc)

## DOING

- Nothing. Both threads are closed and both releases are published.

## Released (2026-08-04, under release control handed over by hv)

| repo        | tag      | at        | contract | suite                    |
| ----------- | -------- | --------- | -------- | ------------------------ |
| arca_cli    | v0.5.0   | 0eb6765   | 57/57    | 785, 6 fixed seeds + 1 unpinned |
| arca_config | v0.3.0   | ccd8fb5   | 38/38    | 222                      |

Both tags annotated, on upstream and the local mirror, trees clean, zero open
issues in either repo.

## What this node did at the end

- Verified the rebuild rather than accepting it: AC-00.1 acked by diffing the
  public `def` surface across the whole thread (85 -> 95, zero modules removed,
  one GenServer callback adjudicated), AC-00.2 executed as a real rebuild,
  AC-06.1 written up at `arca_config/intent/st/COMPLETED/ST0002/vc-rebuild-report.md`.
- Filed issue 0002, then fixed it, then fixed the regression the fix caused, and
  pinned all three cases with mutation-tested coverage.
- Moved the subprocess tests onto the escript, which removed the build-lock
  contention AND a silent skip that had one file reporting "9 passed" while four
  of its tests did nothing.

## Three defects in this node's own instrument, recorded because they cost the most

1. **Phase inferred from a capture label.** A run labelled `release` was graded as
   a pre-bump baseline and reported PASS over two re-swallowed rows. The default
   branch was the lenient one. Now anything not explicitly declared a baseline gates.
2. **The suite verdict was extracted with a regex that dropped the failure.**
   `grep -oE '[0-9]+ (passed|failure).*'` reads `Result: 783/784 passed` as
   `784 passed`, and the `Failed:` line never entered the artifact, so the
   downstream `grep -q failure` had nothing to find. **A release was tagged on a
   failing suite because of this.** The X/Y format was visible in the artifacts and
   I read past it.
3. **The fix for (2) went where `assert` could not reach it**, so the
   discrimination test reported PASS over a synthetic failing verdict. A check
   that cannot fail, twice in one file, in the tool built to detect exactly that.

All three are fixed and each was re-proven on the path actually used. The lesson
is not "be careful" -- it is that a verification tool needs the same adversarial
treatment as the code it verifies, and this node did not give it that until it
had cost something.

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
