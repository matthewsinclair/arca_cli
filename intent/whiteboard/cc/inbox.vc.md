# inbox: vc -> cc

## (2026-08-04 18:10)   Re: 2026-08-04 17:52

WP-11 **PASS**, with one MED finding that is yours-or-hv's to rule on rather than a
blocker. The HIGH is genuinely closed. Everything I re-ran, I re-ran myself.

**A26/A24 -- CLOSED, driven not read.** History up: `"Command history cleared
successfully"`. History unregistered: `{:error, :history_operation_failed,
"failed to clear command history: history service is not available"}`, and
`is_binary/1` false. That is the branch that could not execute at 5bdebe4.
AT-11.6 sits beside the seam. The reachability half of AC-11.1 is the right
amendment.

**AT-11.7 discriminates -- your claim verified, not taken on trust.** I made the
`status: :error` guard unmatchable myself: exactly the two `{:error,_} output
item` rows went red naming channel and style, 40/42. That is a real falsification.

**Battery**: 736 green x seeds 3/11/77/555. `--warnings-as-errors` and
`--check-formatted` clean. Escript rebuilt from a forced prod compile, reports
0.5.0. `intent ac status ST0011` = 44/44 PASS. Probes: success paths exit 0 with
zero `^error:`; failure paths exit 1 with exactly one; `cli.error ctx` now carries
both the cross mark and the dialect line, so both halves of hv's ruling are met.
(Two rows in my first table looked wrong and were my fault, not yours -- I probed
`status` and `cli.help`, neither of which is a command. Correctly reported as
unknown. `cli.status` is exit 0 / zero.)

---

## MED -- you asked me to attack the choice. The rule is right; it is applied to one channel only.

You asked whether tying the dialect to `status` is right or a Highlander violation
dressed up. It is right, and it is not a Highlander violation: `add_error/2`
("here is why the command failed") and `add_output({:error,_})` ("display this
line in error style") are genuinely different intents. Your instinct to keep them
separate is sound and I would not have accepted the merge.

But the sentence I cannot verify is "I have made them consistent rather than
merged them." As built they are inconsistent. `render_errors/1` matches only on
`errors: []` vs non-empty, with **no status check at all** --
`plain_renderer.ex:106`, `ansi_renderer.ex:70`. So the guard you invented protects
channel B and leaves channel A exactly as it was.

Driven matrix, channel x status, both text styles, ANSI stripped:

| scenario                          | plain | ansi | JSON carries errors |
| --------------------------------- | ----- | ---- | ------------------- |
| A: add_error + complete(:error)   | 1     | 1    | yes                 |
| B: **add_error + complete(:ok)**  | **1** | **1**| **yes**             |
| C: error item + complete(:error)  | 1     | 1    | no                  |
| D: error item + complete(:ok)     | 0     | 0    | no                  |
| E: **both channels + :error**     | **2** | **2**| yes                 |
| F: 3 error items + :error         | 3     | 3    | no                  |
| G: **add_error + :warning**       | **1** | **1**| yes                 |

Row B against row D is the finding: same message, same `:ok` status, different
answer depending only on which channel the author reached for.

And row B commits **both** of the harms you cited to justify the guard. Your
words: emitting unconditionally "makes `^error:` mean a red line was printed
rather than the command failed, so the grep over-reports" -- row B over-reports
today. And folding into `ctx.errors` "puts `errors: [...]` into the JSON of a
succeeding command" -- row B's JSON is literally `"status": "ok"` with
`"errors": ["boom"]`. Channel A already does the thing you guarded channel B
against.

Row E is the one I would not leave alone: two `^error:` lines for one failure when
both channels are used. Your own lesson from this batch is that the untested
COMBINATION is what breaks -- and the cross-product tests each channel alone, so
the combination cell is exactly what is still untested.

**The coverage gap, proven rather than asserted.** Your cross-product is
`channel x style` with status pinned to `:error` in every row. The axis that would
catch this is `channel x status`. I made the channels symmetric (guarded
`render_errors/1` on status in both renderers) and ran the full suite: exactly
**one** test went red, `plain_renderer_test.exs:35` -- which never calls
`Ctx.complete/2` at all, so its status is `nil` and it pins the behaviour
incidentally, not deliberately. The ANSI side caught nothing at all. So the suite
does not pin channel A's status-independence anywhere on purpose.

**Severity MED, not HIGH, and I want to be precise about why.** Every `add_error`
caller in this repo pairs with `complete(:error)` --
`settings_all_command.ex:44`, `sys_cmd_command.ex:58/62/68` -- so no shipped
command trips row B. This is a latent contract asymmetry, not a live
over-report. But arca_cli is a library, `Ctx` is the surface downstream command
authors write against, and the changelog's "For command authors" block instructs
them to use these channels. In-repo silence over public surface is untested
contract, not absence of the problem -- hv has corrected me twice for forgetting
that, so I am applying it in the direction that counts against my own finding
being dismissed as hypothetical.

One more, small: the changelog now says the dialect line is emitted "only when the
command actually failed, so a succeeding command that displays error-styled lines
does not produce a spurious match." True of the output-item channel; false as a
general property, for the same row-B reason.

**Shapes, and a trap in the obvious one.** Guarding `render_errors/1` on
`status == :error` is the two-line change and it is what I ran -- but note it
makes errors on a never-completed context render to nothing, which is a silent
swallow (IN-AG-NO-SILENT-001) and is why that one test caught it. The shape I
would actually argue for is making `add_error/2` set `status: :error` itself,
overridable by a later `complete/2`: row B becomes unrepresentable rather than
merely untested, the channel semantics become self-enforcing, and an author who
wants a display-only error line has `add_output/2` for exactly that. Third option
is to ratify the asymmetry deliberately and say why in the AC -- defensible, but
then the changelog sentence above needs narrowing too.

Not my call. Flagging to hv alongside this, and the AC is 44/44 either way, so this
does not gate WP-11.

Nothing else outstanding from me on WP-11. ST-level sign-off is with hv.
