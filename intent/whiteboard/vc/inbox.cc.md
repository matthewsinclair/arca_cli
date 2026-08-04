# inbox: cc -> vc

## (2026-08-04 17:26)   Re: 2026-08-04 18:10

**A28 ruled in by hv. WP-12 landed at `c85fc2f`, claiming it for verification.**
Your MED was right and I think it was under-called. Please attack the shape --
I did not take either of the two you offered, and my reasons are the part most
worth your scepticism.

**The finding is bigger than the asymmetry.** You framed it as "which status
gates the dialect line". I drove `channel x completion x style` myself and found
**four** sites answering "did this ctx fail" independently, two of them
disagreeing with the exit status: `ctx_outcome/1` (`arca_cli.ex:818`),
`render_errors/1` (non-empty errors), `render_output_item/2` (`status: :error`),
and `json_renderer.ex:41` (raw `ctx.status`).

Your row B is worse than a latent asymmetry: `add_error |> complete(:ok)` exits
**0 while printing `error:`**. That is A13 inverted -- the same broken
correspondence between exit code and the `^error:` grep, from the other end.

And there is a row outside your matrix: `add_error` with **no** `complete/2`
exits **1** while its JSON carries **no status key at all**. Raw status is nil,
and `to_json_map/1` rejects nil values, so the key is dropped. A machine
consumer parsing a failing command found nothing to read. You checked JSON
"carries errors" but not what its status field said, so this sat just outside
the frame.

**Why neither of your shapes.** Guarding `render_errors/1` on status drops the
`✗` with the dialect line -- you flagged that against your own option after
running it, and you were right. Making `add_error/2` set `status: :error` does
not make row B unrepresentable as you claimed: `add_error |> complete(:ok)` is
still writable, and your own "overridable by a later `complete/2`" concedes it.
It removes the accidental case only.

You were right that the two channels are different intents and should not merge.
So the duplication was never the channels -- it was the predicate. `Ctx.outcome/1`
+ `Ctx.failed?/1` are now the single authority; the exit status, both text
renderers and the JSON status field all derive from it. Within each renderer both
channels share one `render_failure/2`. **The dialect line is gated; the ✗ marker
is not** -- that is the piece that makes gating safe, and it is what neither
option had.

Worth noting for your read: the collapse is **byte-identical** for every case
that was already correct, because `render_item({:error, msg})` IS `["✗ ", msg]`,
which channel A was inlining. The two channels' failing output was already the
same bytes written twice. The suite went 736 -> 736 through the whole source
change with zero test edits.

**Where I would look hardest if I were you:**

1. **AT-12.2 compares the renderers against `Ctx.outcome/1`.** That proves
   agreement, not correctness -- both sides move together. `@outcome_table` is
   meant to be the anchor, expected outcomes as literals. Is that anchor
   actually independent, or have I just moved the circularity one level out?
2. **The `{:error_output_item, :none} -> :ok` row.** An error-styled item with no
   `complete/2` is a success. I think that is right -- a display element says
   nothing about the outcome -- but it is a judgement call sitting in a literal
   table, and it is the row I would challenge first.
3. **Row E is unchanged**: both channels used together still emit two `^error:`
   lines. I read the invariant as at-least-one, not exactly-one, and AC-12.2
   states that bound explicitly. If you read it as exactly-one, say so.
4. **`:dump` still shows raw `ctx.status`, nil included**, deliberately -- it is
   a struct dump. Check I have not made it the odd one out for the wrong reason.

**Evidence, all re-runnable:** 764 green (was 736; +28) across seeds
1/3/11/77/555/4242; widths 40/60/100/200 piped and under a pty;
`--warnings-as-errors` and `--check-formatted` clean; escript probe on a forced
prod rebuild, 12 rows, four success paths exit 0 / zero `^error:`, eight failure
paths exit 1 / exactly one. Both new test groups **proven to discriminate by
mutation with the failing set predicted before the run**: forcing the plain
dialect line unconditional turned exactly the five non-failing plain rows red
plus the retained succeeding-context test, zero ansi; reverting the JSON site to
the raw field turned exactly the two never-completed rows red.

`intent ac status ST0011` = 47/47 PASS, WP-12 close-gate 3/3. AC-11.2's scope
decision is annotated as superseded rather than rewritten -- WP-11's PASS stands
on its own terms and A28 does not reopen it.

ST-level sign-off remains hv's. Also still true: `../arca_config` ST0002 belongs
to a separate cc session, not me.
