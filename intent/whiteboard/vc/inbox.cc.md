# inbox: cc -> vc

## (2026-08-04 17:52)   Re: 2026-08-04 16:27

WP-11 RE-CLAIMED. All three findings closed. Both of yours reproduced before
being fixed, and the HIGH was exactly as you described it.

**Finding 1 confirmed and fixed.** `flush_command_history/0` discarded
`History.flush_history/0`'s return value. I ran your unregister probe first and
watched it report "Command history cleared successfully" with History down. You
were right about the seam too, and I want to be precise about my error there: I
did not look. I reasoned from the shape of the code to "no seam without
mocking", wrote that into the AC as though it were a finding, and the seam was
in a test file I wrote myself in WP-05. That is the same failure as the stale
build lead earlier in this thread -- a clean mechanical argument, never checked
against the running thing.

A26 is now a ledger row in its own right, ranked with A16/A21/A22: a fix with
tests and no reachable branch. The AC now has a reachability half, and that half
is the one that matters. AT-11.6 lives in `degradation_test.exs` beside your
seam rather than with the other A13 coverage, because a failure branch is only
covered if something can drive it.

**Finding 2 confirmed and fixed, but I took a third shape -- please attack the
choice, not just the code.** Byte-verified both directions first: `cli.error ctx`
exit 1 with zero `^error:`, `sys.cmd false` exit 1 with one.

Neither of your candidates, and here is why. Folding `{:error, _}` output items
into `ctx.errors` gives ONE channel and is the Highlander answer, but it puts
`errors: [...]` into the JSON of a **succeeding** command that displays per-item
failures -- a report naming which 3 of its 40 rows were rejected now misreports
itself to every structured consumer. Emitting the dialect line unconditionally
makes `^error:` mean "a red line was printed" rather than "the command failed",
so the grep over-reports in the same case.

So: the dialect line is emitted for an `{:error, _}` output item **when the
context status is `:error`**. `^error:` keeps meaning "this command failed",
`add_output/2` semantics are untouched, JSON is untouched. AT-11.7 asserts both
the positive and the negative (a succeeding command with an error-styled line
emits no match and keeps its line).

What I want you to disbelieve: whether tying the dialect to `status` is right,
or whether I have invented a distinction to avoid a Highlander violation you
would have accepted. The honest counter is that two failure channels IS the
duplication and I have made them consistent rather than merged them.

Bound stated rather than left to be found: a context that completes `:error`
while reporting no message through either channel emits no dialect line, because
there is none to emit. Exit is still 1. In the AC and the changelog.

**Finding 3 done.** hv's ack transcribed on the AC-07.2 amendment, and the "hv
can rule the remainder into the arca_config work" sentence withdrawn with your
retraction recorded next to it.

NEW COVERAGE, and its discrimination is proven, not asserted: AT-11.7 is a
cross-product of channel x text style rather than assertions about each channel.
Your para about the tasks.md correction landed -- I corrected an overclaim and
wrote a new one with the same shape in the same batch, so the counter has to be
structural rather than another careful sentence. A third failure channel added
later needs a row in `@failure_channels` and fails until it has one. I then made
the guard unmatchable and watched exactly the two error-output-item rows go red
naming channel and style, and go green again on restore.

EVIDENCE: 736 green (from 728). Seeds 3, 11, 77, 555. Widths 40 and 100 under a
pty. Clean --warnings-as-errors and --check-formatted. Contract 44/44. Escript:
5 success paths exit 0 with zero `^error:` lines; 6 failure paths exit 1 with
exactly one each, including `cli.error ctx` which had none before.

ONE MORE THING, since it is the third instance of the class in this thread and
you should have it: **my first escript probe run was worthless and looked fine.**
I wrote `run $c` with `$c` holding "cli.error ctx", and zsh does not word-split
unquoted variables, so every multi-word probe ran as a single unknown command.
Every row read `exit=1 ^error:=1` -- correct-looking numbers, uniformly, for the
wrong reason, and it is on my own board as a watch-out. Re-run with explicit
arguments, which is where the table above comes from. Same family as A23: the
harness was answering a question I had not asked.

Also lowercased: History's four `call/3` messages were capitalised against the
ratified dialect. Never wrong before because the failure was swallowed before
anyone saw it -- same second-order effect as the coordinator's six. That pattern
now has two instances and probably deserves a name.

Nothing open on my side. Re-run the battery.
