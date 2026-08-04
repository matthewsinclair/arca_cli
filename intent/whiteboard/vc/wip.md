---
node: vc
name: Validation Claude
role: validation
session_id: 7a8b32c5-d7d6-4fa9-912b-4e0df57131fb
heartbeat_at: 2026-08-04T16:35Z
status: active
focus: "re-verify cc's WP-11 re-claim (faa5917), then ST0011 sign-off; also vc for arca_config ST0002"
claims: []
---

# Validation Claude (vc)

## DOING

- **PENDING: re-verify cc's WP-11 re-claim** (cc/inbox 17:52 anchor, commit
  faa5917). cc says all three of my findings are closed. Nothing verified yet.
  Live entry is in `vc/inbox.cc.md` -- deliberately NOT cleared, it is unhandled.
- Localfold + compact taken here (2026-08-04 16:35). Status stays `active`, not
  `paused`: a compact does not end a session (whiteboard invariant 6) and work
  resumes immediately. History archived to `.history/20260804/`.

## TODO -- the re-verify battery (self-sufficient; assumes no conversation memory)

1. **A24 / A26 reachability, the HIGH.** `sys_flush_command.ex` must honour
   `History.flush_history/0`'s return instead of discarding it. Drive it, do not
   read it: `MIX_ENV=test mix run --no-compile -e` with
   `Process.unregister(Arca.Cli.History)` then `SysFlushCommand.handle(%{},%{},nil)`
   -- expect `{:error, _, _}`, previously returned "Command history cleared
   successfully". Confirm AT-11.6 lives in `degradation_test.exs` and that the AC
   now has a reachability half.
2. **Finding 2, and cc has explicitly asked me to attack its CHOICE.** cc rejected
   both my shapes and tied the dialect line to `status == :error` for
   `{:error,_}` output items. Its reasoning: folding error items into
   `ctx.errors` would put `errors: [...]` into the JSON of a *succeeding* command
   that reports per-item failures, and emitting unconditionally would make
   `^error:` mean "a red line was printed" rather than "the command failed". Its
   own stated counter, which I must weigh: two failure channels IS the
   duplication, and it has made them consistent rather than merged them. Judge
   whether that is a real distinction or a Highlander violation dressed up.
   Probe: `cli.error ctx` piped AND under pty -> exit 1, one `^error:`, cross
   mark; a succeeding command with an error-styled item -> zero `^error:`,
   line still shown. Check the stated bound too: ctx completes `:error` with no
   message in either channel -> no dialect line, exit still 1.
3. **AT-11.7's discrimination.** cc claims a cross-product guard (channel x text
   style) with `@failure_channels`, and says it made the guard unmatchable and
   watched exactly the two error-output-item rows go red naming channel and
   style. Re-run that falsification myself -- a guard that cannot fail is the
   A16/A21/A22/A26 archetype again, which is the whole point of the row.
4. **Finding 3**: AC-07.2 hv ack transcribed in `acceptance.md`, and the "hv can
   rule the remainder into the arca_config work" sentence withdrawn with my
   retraction recorded beside it.
5. **Both changelog completeness sentences** corrected -- "None outstanding for
   the exit-code contract" and the `grep '^error:'` claim were false at 5bdebe4.
6. **Regression guard**: A18 / A19 / A20 / A25 verified clean at 5bdebe4 --
   confirm they did not move. Width matrix was 91 green at 40/60/100/200 (pty).
7. **Battery**: fresh seeds piped + pty, `--warnings-as-errors`,
   `--check-formatted`, escript rebuilt, `intent ac status ST0011` = PASS, escript
   probes (success paths exit 0 with zero `^error:`; failure paths exit 1 with
   exactly one). cc claims 736 green, seeds 3/11/77/555, contract 44/44.
8. **Then**: ST-level sign-off is mine to give. `intent st done ST0011` is
   deliberately not run by cc -- the release is hv's call.

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
