---
verblock: "04 Aug 2026:v0.1: matts - Initial version"
wp_id: WP-11
title: "Closing batch: A13 residue, renderer dialect, width pins, changelog gap"
scope: Small
status: Done
---

# WP-11: Closing batch: A13 residue, renderer dialect, width pins, changelog gap

## Objective

Close the last of finding A13 so the release's headline claim is true without a footnote, and close the gaps vc's verification pass found.

0.5.0's headline is that a command's outcome reaches the shell. That claim had four known exceptions when WP-10 shipped: `sys.flush`, `cfg.list`, `BaseSubCommand` and the coordinator all reported failure as ordinary output and exited 0. They were named under "Known limitations" rather than shipped silently, pending an hv ruling. hv ruled all fixes into this version, so this WP removes the footnote rather than documenting it better.

## Deliverables

- [x] A18 -- `Arca.Cli.Command.BaseSubCommand.handle/3` returns error tuples. The most important of the four: it is the shared base every subcommand inherits, so a failing subcommand exited 0 in every downstream application too.
- [x] A19 -- `cfg.list` returns its error tuple. An empty configuration stays a success, matching what `settings.all` already does.
- [x] A20 -- `Coordinator.inject_subcommands/2` and `update_command_names/3` report a broken command set instead of silently shrinking the CLI.
- [x] A24 -- `sys.flush` returns its error tuple.
- [x] Ctx renderer error dialect, per hv's "both" ruling: `:ansi` and `:plain` emit `error: <command>: <message>` alongside the `✗` block; `:json` unchanged.
- [x] A25 (found while doing the above) -- the `:ansi` renderer rendered `ctx.errors` not at all. An error-only context produced the empty string in the one style a human reads.
- [x] Renderer tests pinned to a fixed `:max_width`, closing vc's N2. Terminal width is no longer an input to the suite.
- [x] CHANGELOG "For command authors" block, closing vc's MED finding from the AC-10.1 reverse walk: six downstream-relevant changes that had no entry.
- [x] Ledger rows A18, A19, A20, A24, A25, C13; the A24 OPEN row resolved.

## Dependencies

- hv ruling "all fixes go into this version", relayed by vc 2026-08-04. Without it the A13 residue stays documented rather than fixed.
- hv ruling on the Ctx renderer dialect ("both": keep the cross-mark presentation and emit a `^error:` line).
- WP-08's ratified dialect and WP-03's loud `setup/1`, both of which this WP's fixes plug into rather than reinvent.
