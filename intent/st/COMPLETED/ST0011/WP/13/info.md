---
verblock: "04 Aug 2026:v0.2: matts - As-built"
wp_id: WP-13
title: "Config load diagnosis survives to the user"
scope: Small
status: Done
---

# WP-13: Config load diagnosis survives to the user

## Objective

When configuration cannot be loaded, tell the user why. Closes A29, filed by vc from a cross-repo probe.

## Deliverables

- `cfg_commands.ex` -- `load_settings/0` pattern-matches instead of strict-matching, so the reason from `Arca.Cli.load_settings/0` reaches the user. The bare `rescue` that logged a raw struct and substituted `"Unknown error loading settings"` is gone; unexpected exceptions are reported by `execute_command/5`, which already carries their real message. The `@dialyzer {:nowarn_function}` above it went with the strict match that made it necessary.
- `arca_cli.ex` -- the startup warning in `run/1` carried no reason at all (`"Error loading settings"`). It now names it. This is the same defect one level up, and it is what made vc's `about` / `cli.status` observation noisy-but-useless rather than merely noisy.
- `arca_cli.ex` -- `load_settings/0`'s two messages moved to the ratified dialect: lowercase, and `reason_text/1` in place of `inspect/1` so a binary reason does not arrive wrapped in quotes. The rescue reports `Exception.message/1` rather than `inspect(e)`, so no exception struct reaches a user-facing line.
- `test/arca_cli/config_diagnosis_test.exs` -- 8 tests driving a real unparseable config through a subprocess.

## Acceptance

Acceptance Criteria for this work package live in the steel thread's `acceptance.md`, under the `WP-13` heading (single source of truth). Do not restate ACs here.

## As built

**A29 is live on the current pin, which is not how it was filed.** vc found it by building against the unreleased arca_config and reported it as dormant until the dep bump, because the pinned arca_config silently falls back when a config file is MISSING. But a config file that EXISTS and does not parse reaches the identical path on the pinned dependency:

    $ cfg.list        # before, config present and unparseable
    [error] Error loading settings: %MatchError{term: {:error, "Failed to load configuration: ..."}}
    error: cfg.list: Unknown error loading settings

    $ settings.all    # same trigger, same repo, same underlying call
    error: settings.all: Failed to load configuration: "Error parsing config at position: 2, token: ''"

So it needed neither the bump nor a local arca_config to reproduce, and it is fixed and verified now rather than prepared for later. hv's single-bump ruling is not engaged: nothing here changes a dependency.

**Making the failure visible is what made its wording matter, for the third time in this thread.** The reason had been reaching a `MatchError` rather than a person, so nobody had read it. Once it reached the dialect line it was capitalised and carried `inspect/1` quotes, both against the ratified form. Same sequence as the coordinator's six messages and History's four in WP-11.

## Verification

- 772 green (was 764) across seeds 1/3/11/77/555/4242; `--check-formatted` and `--warnings-as-errors` clean.
- Both fixes proven to discriminate by mutation, with the failing set predicted before each run: reverting `cfg_commands.ex` turns exactly 4 red, reverting the startup warning exactly 1.
- **The first version of these tests was weaker than it looked.** Mutation predicted 4 red and produced 2: the harness row and the two-readers row passed against the reverted fix, because the leaked `%MatchError{}` contains the reason string, so assertions scanning the whole output found it while the user was still being told "Unknown error loading settings". They now read the dialect line specifically -- what the user is actually told -- and the mutation produces the predicted 4.
- vc's harness (`intent/whiteboard/vc/probes/`) run before and after: PASS both times, behaviour probe **identical**. That is a blind spot rather than a reassurance, and it is reported to vc: the harness probes only the missing-config trigger, which this pin falls back on, so it cannot see A29 or its fix. A `BADCFG` row -- config present, unparseable -- would fire on both pins.

## Dependencies

- None. Independent of the arca_config bump in both directions: the defect reproduces without it, and the fix needs nothing from it.
