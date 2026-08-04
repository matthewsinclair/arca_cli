---
verblock: "04 Aug 2026:v0.1: matts - Initial version"
wp_id: WP-09
title: "Remove test-env branching from lib"
scope: Medium
status: Not Started
---

# WP-09: Remove test-env branching from lib

## Objective

Production code must not know it is being tested; the suite must exercise the pipeline production runs. Findings: C6 (13 `Mix.env()` sites across 5 lib files).

## Deliverables

- `settings.all`: delete `build_test_context` fabrication; tests seed real settings through the real path.
- `main/1`: one display path (the test-only branch merges into the production branch; WP-01's `run/1` largely does this).
- `load_settings` / `get_setting` / `save_settings`: replace `:test_settings` app-env branching with a config-backed settings source (the test suite points Arca.Config at a temp dir -- `CliCommandHelper.with_clean_config` already provides this pattern).
- `history_maybe_child_spec` / `config_available?`: replace `Mix.env()==:test` checks with capability checks that hold in all envs. NOTE (found in WP-05): the `Mix.env() == :test && is_pid(Process.whereis(History))` branch never fires. The application starts before `test_helper.exs` runs, so History is not yet registered at that moment and the supervisor is always started -- meaning History IS supervised under test, contrary to the comment above it. Anything relying on that branch is relying on something that does not happen.
- `Output.test_env?` MIX_ENV env-var check removed (style in tests comes from `ARCA_STYLE=plain`, which the test helper already sets).
- `namespace_command_helper` / `dev_info` Mix references resolved by WP-06; this WP sweeps the stragglers and adds a CI guard: `grep -c "Mix.env()" lib/` must be 0.
- `lib/arca_cli/testing/cli_fixtures_test.ex` carries 2 of the 13 `Mix.env()` sites -- a test fixture living inside `lib/`. Clean it or relocate it, or the AC-09.1 grep-zero gate cannot pass (vc, 2026-08-04).
- Full suite migrated and green; no `Application.put_env(:arca_cli, :test_settings, ...)` remains in tests.

Note: `main/1`'s test-only display branch was NOT merged by WP-01 -- WP-01 moved it intact into `run/1`'s `display_response/1` to hold AC-01.4 (display unchanged). Collapsing the two branches is still this WP's job.

## Acceptance

Acceptance Criteria for this work package live in the steel thread's `acceptance.md`, under the `WP-09` heading (single source of truth). Do not restate ACs here.

## Dependencies

- WP-01 (run/1 collapses main's dual display path); WP-06 (dev.* Mix removal). Highest-risk WP -- the suite currently leans on these branches; budget for test rework. Candidate to defer to 0.5.1 if hv wants to shrink 0.5.0 -- flagged, not assumed.
