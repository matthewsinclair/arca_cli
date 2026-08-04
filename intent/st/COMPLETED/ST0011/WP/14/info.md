---
verblock: "04 Aug 2026:v0.2: matts - As-built"
wp_id: WP-14
title: "Pin the arca_config contract"
scope: Small
status: Done
---

# WP-14: Pin the arca_config contract

## Objective

State the arca_config surface this CLI depends on, in one place, as a test -- so the dep bump breaks a build rather than someone's terminal. Closes A30 and A31, both found by following up vc's cross-repo observation.

## Deliverables

- `arca_cli.ex` -- `load_settings/0` calls `Arca.Config.reload/0` instead of `Arca.Config.Server.reload/0`. Same delegation target, present in both the pinned and the unreleased arca_config.
- `cli_command_helper.ex` -- the `@moduledoc` example no longer tells readers to call `Arca.Config.get_config_location/0`, which does not exist in the pinned dependency at all. It uses `Arca.Config.Cfg.config_file/0`, which does exist in both.
- `test/arca_cli/config_contract_test.exs` -- 8 tests pinning the facade calls, the two unavoidable Server calls, and the liveness probe.

## Acceptance

Acceptance Criteria for this work package live in the steel thread's `acceptance.md`, under the `WP-14` heading (single source of truth). Do not restate ACs here.

## As built

**A30 -- the hottest path in the CLI was on another repo's internals.** `Arca.Cli.load_settings/0` called `Arca.Config.Server.reload/0`, past the public module. `run/1` loads settings before dispatch for *every* command, so that call is on the path for every invocation. arca_cli tracks arca_config by git branch and every one of these calls resolves at runtime, so a rename there produces no compiler error here -- it produces a crash in a user's terminal after a `mix deps.update`.

The full executable surface, which turns out to be small:

| call                                  | site                          | status                          |
| ------------------------------------- | ----------------------------- | ------------------------------- |
| `Arca.Config.get/1`, `put/2`          | `arca_cli.ex:1075,1156`       | facade, both versions           |
| `Arca.Config.switch_config_location/1` | `cli_command_helper.ex:500,509` | facade, both versions         |
| `Arca.Config.Server.reload/0`         | `arca_cli.ex:1032`            | **moved to the facade**         |
| `Arca.Config.Server.start_link/1`     | `cli_command_helper.ex:549`   | no facade in either -- pinned   |
| `Arca.Config.Server.delete/1`         | `test_helper.exs:83`          | facade only in local -- pinned  |

vc established that arca_config's own consumer-contract test pins its facade `delete/1` and pins neither `Server.delete/1` nor `Server.start_link/1`, so nothing on that side would notice their removal. That gap is what this WP covers.

**A31 -- a shipped moduledoc documented a function that does not exist.** `cli_command_helper.ex` ships in `lib/`, and its module documentation told readers to call `Arca.Config.get_config_location/0`. That function is absent from the pinned arca_config entirely -- confirmed at runtime, `function_exported?` is false -- and present only in the unreleased one. Anyone following the documented example got an `UndefinedFunctionError`.

I first read this as a live crash on a shipped code path and was wrong: line 350 is inside the `@moduledoc`, which runs to line 375. Checking reachability before reporting is what caught it. The severity is documentation, not runtime.

**The liveness probe is pinned twice, deliberately.** `Arca.Cli.config_available?/0` probes `function_exported?(Arca.Config, :register_change_callback, 2)`. Nothing here calls that function -- WP-07 deleted the callback subsystem -- so a call-graph search from the arca_config side cannot find this consumer, and retiring it there silently flips `config_available?` to false and degrades every `save_settings`. This was a written watch-out on the cc board; it is now a mechanical check.

The second pin asserts that `config_available?/0` still probes the function this file names. Without it, changing the probe to some other function would leave the existence assertion true of arca_config while no longer describing what this CLI relies on -- a test passing for the wrong reason.

## Verification

- 780 green (was 772) across seeds 1/11/555; `--check-formatted` and `--warnings-as-errors` clean.
- Proven to discriminate by mutation, failing set predicted first: adding a function arca_config does not export turns exactly 1 red; repointing `@liveness_probe` at a *different real* function also turns exactly 1 red -- and that one matters, because `notify_callbacks/0` does exist, so the existence assertion passed and only the source check caught the drift.

## Dependencies

- None. Both fixes work against the pinned dependency; neither needs the bump.
