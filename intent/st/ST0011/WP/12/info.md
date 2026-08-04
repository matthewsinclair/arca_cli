---
verblock: "04 Aug 2026:v0.2: matts - As-built"
wp_id: WP-12
title: "One predicate for Ctx failure"
scope: Small
status: Done
---

# WP-12: One predicate for Ctx failure

## Objective

Make one function the authority on whether a `Ctx` failed, and have every consumer of that question derive from it: the OS exit status, the `error:` dialect line in both text renderers, and the JSON status field.

Closes A28, filed by vc as a MED against WP-11 and ruled in by hv.

## Deliverables

- `Arca.Cli.Ctx.outcome/1` and `Ctx.failed?/1` -- the single authority, holding the rule that was previously private to dispatch: an explicit `complete/2` status wins, and failing that a context carrying errors is a failure.
- `arca_cli.ex` -- private `ctx_outcome/1` deleted; `process_command_result/3` calls `Ctx.outcome/1`.
- `plain_renderer.ex` and `ansi_renderer.ex` -- both failure channels (`add_error/2` and `{:error, _}` output items) now render through one `render_failure/2` per renderer. The dialect line is gated on `Ctx.failed?/1`; the `✗` marker is not gated at all.
- `json_renderer.ex` -- reports `Ctx.outcome/1` rather than the raw `ctx.status` field.
- `renderer_parity_test.exs` -- the failure cross-product moves from `channel x style` to `channel x completion x style`, asserts a biconditional rather than presence, and gains a literal outcome table plus a JSON agreement product.

## As built

The unification is byte-identical for every case that was already correct. In both renderers, channel A's failing output (`[error_line, "\n✗ ", msg]`) and channel B's (`[error_line, "\n", render_item({:error, msg})]`) expand to the same bytes, because `render_item({:error, msg})` **is** `["✗ ", msg]`. So collapsing them onto one function changed nothing except the two rows that were wrong. That is why the suite stayed green at 736 through the source change with zero test edits -- the same signal WP-11 round one gave, and the same meaning: nothing was exercising these paths.

Two behaviour changes, both driven before and after:

| context                          | before                          | after                          |
| -------------------------------- | ------------------------------- | ------------------------------ |
| `add_error \|> complete(:ok)`    | exit 0, prints `error:`         | exit 0, no `error:`, ✗ kept    |
| `add_error` with no `complete/2` | exit 1, JSON has no status key  | exit 1, JSON `"status":"error"` |

`:dump` still shows the raw `ctx.status` including `nil`, deliberately: it is a struct dump for debugging, and misreporting the field as an outcome would defeat its purpose.

## Verification

- 764 green (was 736; +28 net) across seeds 1/3/11/77/555/4242.
- Widths 40/60/100/200, piped and under a pty.
- `mix format --check-formatted` and `mix compile --warnings-as-errors` clean, test env included.
- Escript probe, forced prod rebuild, 12 rows: four success paths exit 0 with zero `^error:`, eight failure paths exit 1 with exactly one. The table carries its own control -- the two groups differ, so the harness is shown to distinguish rather than printing one uniform answer.
- Both new test groups proven to discriminate by mutation, with the failing set predicted before the run in each case. See AT-12.2 and AT-12.3.

## Dependencies

- Follows WP-11, which vc PASSed. A28 was filed against that PASS and does not reopen it: WP-11's ACs remain satisfied on their own terms, and the AC-11.2 scope-decision note is annotated as superseded rather than rewritten.
