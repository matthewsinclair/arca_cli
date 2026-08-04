---
id: "0001"
title: Every command exits 0: main/1 hardcodes :ok and nothing calls System.halt
date: 2026-08-04
reporter: matts
status: OPEN
severity: high
---

# 0001: Every command exits 0: main/1 hardcodes :ok and nothing calls System.halt

## Tags

exit-code, ctx, main, automation, silent-failure

## Summary

An arca_cli command cannot fail, as far as the operating system is concerned. `Arca.Cli.main/1` ends with a hardcoded `:ok`, no code path anywhere in `lib/` calls `System.halt` or `System.stop`, and the one field that records how a command went -- `Ctx.status` -- is consumed by nothing except the `--dump` debug renderer. The result is that every command in every downstream project exits 0 whatever happened, so any script, CI step, or shell conditional that gates on a command's exit status is silently blind.

This is a correctness bug rather than a missing feature, because `Ctx.complete/2` is public, documented API that invites callers to declare `:error` and then does not act on it. A command author reasonably concludes they have reported failure.

## Reproduction

Observed in Laksa (2026-08-03), which consumes arca_cli via `{:arca_cli, github: "matthewsinclair/arca-cli", branch: "main"}`.

    $ bin/laksa_cli laksa.site.show definitelynotasite
    ✗ Invalid or expired API key
    ℹ Run 'laksa.auth.login <api-key>' with a new key

    $ bin/laksa_cli laksa.site.show definitelynotasite >/dev/null 2>&1; echo "exit=$?"
    exit=0

The command errored, said so on screen in red, and exited 0.

Reproduces for any failing command; the auth failure above is just the cheapest one to trigger. It is not specific to the consuming project -- nothing in Laksa's own code could change it.

## Root Cause

Three findings, each verified against `main` at `0f97f9f`:

1. **`Arca.Cli.main/1` discards the outcome deliberately.** Its final expression is:

       # Always return :ok to prevent the error from appearing in shell output
       :ok

   The comment names the motive, and the motive is cosmetic: an error tuple returned from a mix task gets echoed by the shell. That is a real annoyance, but it was solved by destroying the information rather than by formatting it. Everything upstream of this line -- the `{:error, error_type, reason, debug_info}` branch, `handle_error/1`, the formatted output -- has already done the work of knowing the command failed. The knowledge exists and is thrown away on the last line.

2. **Nothing calls `System.halt` or `System.stop`.** `grep -rn "System.halt\|System.stop" lib/` returns no matches. So even a caller that inspected `main/1`'s return has nothing to act on, and the BEAM exits 0 by default.

3. **`Ctx.status` is inert.** `Ctx.complete/2` (`lib/arca_cli/ctx.ex:262`) sets the field and is documented as "Sets the final status of the command execution". The only read of that field in the whole library is `lib/arca_cli/output.ex:125`, inside `dump_context/1` -- the `:dump` renderer, used for debugging. No renderer, no dispatcher, and no entry point consults it otherwise.

The three compound: a command declares `:error`, the status is stored, the status is never read, `main/1` returns `:ok` regardless, and no one halts.

## Impact

Every downstream consumer, not just the reporting one.

- **CI and scripts cannot detect failure.** `set -e`, `cmd && next`, and any pipeline step gating on exit status all treat a failed command as success. In Laksa this means a content sync that failed files, or a purge that aborted on its own safety guard, is indistinguishable from a clean run to anything but a human reading the screen.
- **The failure mode is silent and inverted.** The command is loud on screen and silent to automation, so the more carefully something is guarded, the more likely the guard is bypassed. A safety abort that prints "Safety check FAILED" and "No changes were made" still reports success to the caller.
- **`Ctx.complete/2` is a trap for command authors.** It is the obvious API for reporting failure, it type-checks, it stores the value, and it does nothing. A command author fixing an exit-code bug will reach for it, ship, and believe the bug is closed. (That happened in Laksa: `laksa.content.sync` was corrected to call `Ctx.complete(:error)` in commit `70c45e4c`, and the exit code did not move. The commit says so explicitly to stop the next reader believing otherwise.)

## Proposed Fix

The shape that addresses all three findings without reintroducing the shell echo that motivated the hardcoded `:ok`:

1. **Surface the outcome from `main/1`.** Return something the caller can branch on -- either the `Ctx` itself, or a normalised `:ok | {:error, term}`. Keep the current formatting behaviour exactly as it is; the display path already handles errors properly and should not change.

2. **Halt at the entry point, not in `main/1`.** The escript / mix-task boundary is the right place for `System.halt(1)`, so library consumers embedding `main/1` are unaffected and only the process entry point exits. This also preserves the original motive: the shell never sees a returned error tuple, because the return value is consumed by the halt decision rather than echoed.

3. **Make `Ctx.status` load-bearing.** Have the dispatcher fold a command's `Ctx.status` into `main/1`'s outcome, so `Ctx.complete(:error)` means what its docs say. Today a command has no working way to signal failure other than returning an error tuple, which makes the documented API misleading.

Worth deciding explicitly as part of the fix: whether `:warning` should exit 0 or non-zero. `Ctx.complete/2` accepts `:ok | :error | :warning`, and downstream commands use `:warning` for "completed, with notes", which argues for 0.

A regression test should assert the process exit code, not the return value -- a test that only checks `main/1`'s return would have passed throughout the life of this bug.

## Related

- Laksa `70c45e4c` -- a downstream command corrected to call `Ctx.complete(:error)`, documenting that the exit code is still 0 and why
- Laksa `docs/howto/prod-orphan-purge.md` -- a production runbook that instructs the operator to read command output rather than trust its status; currently correct by accident

## Resolutions

{{TBC}}
